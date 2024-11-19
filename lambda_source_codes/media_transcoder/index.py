import json
import os
import boto3
from urllib.parse import urlparse
import uuid

# Initialize AWS clients for S3 and MediaConvert
s3_client = boto3.client('s3')
mediaconvert_client = boto3.client('mediaconvert')

def lambda_handler(event, context):
    # Log the event to inspect its structure
    print(f"Received event: {json.dumps(event)}")

    # Destination bucket and MediaConvert role from environment variables
    destination_bucket = os.environ['DESTINATION_BUCKET']
    mediaconvert_role = os.environ['MEDIACONVERT_ROLE']
    
    # Process each record in the SQS event
    for record in event['Records']:
        try:
            # Parse the message body from the SQS record
            try:
                message_body = json.loads(record['body'])
                print(f"Message body parsed successfully: {message_body}")
            except json.JSONDecodeError as e:
                print(f"Error parsing message body: {str(e)}")
                continue

            # Extract S3 information from the message
            try:
                s3_info = message_body['Records'][0]['s3']
                source_bucket = s3_info['bucket']['name']
                s3_key = s3_info['object']['key']
                print(f"S3 bucket: {source_bucket}, S3 key: {s3_key}")
            except KeyError as e:
                print(f"Key error accessing S3 info: {str(e)}")
                continue

            # Identify the folder name and file name from the S3 key
            folder_name = s3_key.split('/')[0]
            file_name_with_extension = s3_key.split('/')[-1]
            output_folder = os.path.splitext(file_name_with_extension)[0]

            # Try to load the corresponding JSON configuration from S3
            config_key = f"transcoder_config/{folder_name}.json"
            try:
                job_settings = load_json_config(source_bucket, config_key)
                print(f"Loaded job settings from {config_key}")
            except Exception as e:
                print(f"Error loading configuration: {str(e)}")
                continue

            # Modify the MediaConvert job settings with the input file and output paths
            try:
                source_s3 = f"s3://{source_bucket}/{s3_key}"
                modify_job_settings(job_settings, source_s3, output_folder, destination_bucket)
                print(f"Job settings modified for source: {source_s3}")
            except Exception as e:
                print(f"Error modifying job settings: {str(e)}")
                continue

            # Metadata for the MediaConvert job
            job_metadata_dict = {
                'assetID': str(uuid.uuid4()),
                'application': 'MediaConvertApp',
                'input': source_s3,
                'settings': f"{folder_name}.json"
            }

            # Create the MediaConvert job
            try:
                print(f"Creating MediaConvert job with settings: {json.dumps(job_settings)}")
                mediaconvert_client.create_job(
                    Role=mediaconvert_role,
                    UserMetadata=job_metadata_dict,
                    Settings=job_settings,
                )
                print(f"Job created for {source_s3} with output in {destination_bucket}/{output_folder}/")
            except Exception as e:
                print(f"Error creating MediaConvert job: {str(e)}")
                continue

        except Exception as error:
            # Log any unforeseen errors that occur during processing
            print(f"Unexpected error: {str(error)}")
            raise  # Re-throw the error to let Lambda's DLQ (if configured) handle it

    return {
        'statusCode': 200,
        'body': 'SQS processing completed successfully!'
    }

def get_mediaconvert_endpoint(region):
    """Retrieve the MediaConvert endpoint for the specified region."""
    mediaconvert_client = boto3.client('mediaconvert', region_name=region)
    endpoints = mediaconvert_client.describe_endpoints()
    return endpoints['Endpoints'][0]['Url']

def load_json_config(bucket, key):
    """Load the JSON configuration file from S3."""
    response = s3_client.get_object(Bucket=bucket, Key=key)
    config_json = response['Body'].read().decode('utf-8')
    return json.loads(config_json)


def modify_job_settings(job_settings, source_s3, output_folder, destination_bucket):
    """Modify the MediaConvert job settings with input and output configurations."""
    job_settings['Inputs'][0]['FileInput'] = source_s3
    output_base = f"s3://{destination_bucket}/{output_folder}/"
    for output_group in job_settings['OutputGroups']:
        output_group_type = output_group['OutputGroupSettings']['Type']
        output_group_settings_key = get_output_group_settings_key(output_group_type)
        if output_group_settings_key:
            output_group['OutputGroupSettings'][output_group_settings_key]['Destination'] = \
                output_base + urlparse(output_group['OutputGroupSettings'][output_group_settings_key]['Destination']).path
        else:
            raise ValueError(f"Unknown Output Group Type: {output_group_type}")

def get_output_group_settings_key(output_group_type):
    """Map the output group type to the corresponding configuration key."""
    output_group_type_dict = {
        'HLS_GROUP_SETTINGS': 'HlsGroupSettings',
        'FILE_GROUP_SETTINGS': 'FileGroupSettings',
        'CMAF_GROUP_SETTINGS': 'CmafGroupSettings',
        'DASH_ISO_GROUP_SETTINGS': 'DashIsoGroupSettings',
        'MS_SMOOTH_GROUP_SETTINGS': 'MsSmoothGroupSettings'
    }
    return output_group_type_dict.get(output_group_type)
