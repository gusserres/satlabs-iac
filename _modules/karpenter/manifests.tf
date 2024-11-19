######################################################
# Karpenter NodePool
# https://karpenter.sh/v0.37/concepts/nodepools/
######################################################
resource "kubernetes_manifest" "node_pool" {
  for_each   = var.manifest_enabled ? var.karpenter : {}
  depends_on = [helm_release.karpenter_crd, helm_release.karpenter]
  manifest = {
    apiVersion = "karpenter.sh/v1"
    kind       = "NodePool"
    metadata = {
      name = each.key
    }
    # Template section that describes how to template out NodeClaim resources that Karpenter will provision
    # Karpenter will consider this template to be the minimum requirements needed to provision a Node using this NodePool
    # It will overlay this NodePool with Pods that need to schedule to further constrain the NodeClaims
    # Karpenter will provision to launch new Nodes for the cluster
    spec = {
      # Template section that describes how to template out NodeClaim resources that Karpenter will provision
      # Karpenter will consider this template to be the minimum requirements needed to provision a Node using this NodePool
      # It will overlay this NodePool with Pods that need to schedule to further constrain the NodeClaims
      # Karpenter will provision to launch new Nodes for the cluster
      template = {
        metadata = {
          # Labels are arbitrary key-values that are applied to all nodes
          labels = length(each.value.node_labels) > 0 ? merge(each.value.node_labels, { "karpenter-node-pool" = each.key }) : { "karpenter-node-pool" = each.key }
          # Annotations are arbitrary key-values that are applied to all nodes
          annotations = length(each.value.node_annotations) > 0 ? each.value.node_annotations : {}
        }
        spec = {

          # References the Cloud Provider's NodeClass resource, see your cloud provider specific documentation
          nodeClassRef = {
            group = "karpenter.k8s.aws"
            kind  = "EC2NodeClass"
            name  = each.key
          }

          # Provisioned nodes will have these taints
          # Taints may prevent pods from scheduling if they are not tolerated by the pod.
          taints = length(each.value.taints) > 0 ? each.value.taints : []

          # Provisioned nodes will have these taints, but pods do not need to tolerate these taints to be provisioned by this
          # NodePool. These taints are expected to be temporary and some other entity (e.g. a DaemonSet) is responsible for
          # removing the taint after it has finished initializing the node.
          # startupTaints = [
          #   {
          #     key    = "example.com/startup-taint"
          #     effect = "NoSchedule"
          #   }
          # ]

          # The amount of time a Node can live on the cluster before being removed
          # Avoiding long-running Nodes helps to reduce security vulnerabilities as well as to reduce the chance of issues that can plague Nodes with long uptimes such as file fragmentation or memory leaks from system processes
          # You can choose to disable expiration entirely by setting the string value 'Never' here
          expireAfter = "168h"

          # The amount of time that a node can be draining before it's forcibly deleted. A node begins draining when a delete call is made against it, starting
          # its finalization flow. Pods with TerminationGracePeriodSeconds will be deleted preemptively before this terminationGracePeriod ends to give as much time to cleanup as possible.
          # If your pod's terminationGracePeriodSeconds is larger than this terminationGracePeriod, Karpenter may forcibly delete the pod
          # before it has its full terminationGracePeriod to cleanup.

          # Note: changing this value in the nodepool will drift the nodeclaims.
          terminationGracePeriod : "48h"


          # Labels are arbitrary key-values that are applied to all nodes
          # Requirements that constrain the parameters of provisioned nodes.
          # These requirements are combined with pod.spec.topologySpreadConstraints, pod.spec.affinity.nodeAffinity, pod.spec.affinity.podAffinity, and pod.spec.nodeSelector rules.
          # Operators { In, NotIn, Exists, DoesNotExist, Gt, and Lt } are supported.
          # https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#operators
          requirements = [
            {
              key      = "karpenter.sh/capacity-type"
              operator = "In"
              values   = each.value.is_spot == true ? ["spot"] : ["on-demand"]
            },
            {
              key      = "kubernetes.io/arch"
              operator = "In"
              values = [
                "amd64",
              ]
            },
            {
              key      = "karpenter.k8s.aws/instance-family"
              operator = "In"
              values   = each.value.instance_type != [""] ? each.value.instance_type : var.instance_type
            },
            {
              key      = "karpenter.k8s.aws/instance-size"
              operator = "In"
              values   = each.value.instance_size != [""] ? each.value.instance_size : var.instance_size
            },

          ]
        }
      }
      # Disruption section which describes the ways in which Karpenter can disrupt and replace Nodes
      # Configuration in this section constrains how aggressive Karpenter can be with performing operations
      # like rolling Nodes due to them hitting their maximum lifetime (expiry) or scaling down nodes to reduce cluster cost
      disruption = {
        # Describes which types of Nodes Karpenter should consider for consolidation
        # If using 'WhenUnderutilized', Karpenter will consider all nodes for consolidation and attempt to remove or replace Nodes when it discovers that the Node is underutilized and could be changed to reduce cost
        # If using `WhenEmpty`, Karpenter will only consider nodes for consolidation that contain no workload pods
        consolidationPolicy = "WhenEmptyOrUnderutilized"

        # The amount of time Karpenter should wait to consolidate a node after a pod has been added or removed from the node.
        # You can choose to disable consolidation entirely by setting the string value 'Never' here
        consolidateAfter : "5m" # Added to allow additional control over consolidation aggressiveness


        # Budgets control the speed Karpenter can scale down nodes.
        # Karpenter will respect the minimum of the currently active budgets, and will round up
        # when considering percentages. Duration and Schedule must be set together.
        # budgets = [
        #   {
        #     nodes = "10%"
        #   },
        #   # On Weekdays during business hours, don't do any deprovisioning.
        #   {
        #     schedule = "0 9 * * mon-fri"
        #     duration = "8h"
        #     nodes    = "0"
        #   }
        # ]
        budgets = length(each.value.budgets) > 0 ? each.value.budgets : []
      }

      # Resource limits constrain the total size of the pool.
      # Limits prevent Karpenter from creating new instances once the limit is exceeded.
      limits = {
        cpu    = each.value.limits.cpu
        memory = each.value.limits.memory
      }

      # Priority given to the NodePool when the scheduler considers which NodePool
      # to select. Higher weights indicate higher priority when comparing NodePools.
      # Specifying no weight is equivalent to specifying a weight of 0.
      # weight = "10"
    }
  }
  computed_fields = ["spec.template.metadata.labels", "spec.template.metadata.annotations", "spec.template.spec.taints"]
  field_manager {
    force_conflicts = true
  }
  timeouts {
    create = "1m"
    update = "1m"
    delete = "1m"
  }
}

######################################################
# Karpenter EC2NodeClass
# https://karpenter.sh/v0.36/concepts/nodeclasses/
######################################################
resource "kubernetes_manifest" "ec2_node_class" {
  for_each   = var.manifest_enabled ? var.karpenter : {}
  depends_on = [helm_release.karpenter_crd, helm_release.karpenter]
  manifest = {
    apiVersion = "karpenter.k8s.aws/v1"
    kind       = "EC2NodeClass"
    metadata = {
      name = each.key
    }

    spec = {
      # Karpenter provides the ability to specify a few additional Kubelet args.
      # These are all optional and provide support for additional customization and use cases.
      kubelet = {
        imageGCHighThresholdPercent = "70"
        imageGCLowThresholdPercent  = "50"
      }

      # Required, resolves a default ami and userdata
      amiFamily = lookup(each.value, "ami_family", "AL2023")

      # Required, discovers subnets to attach to instances
      # Each term in the array of subnetSelectorTerms is ORed together
      # Within a single term, all conditions are ANDed
      subnetSelectorTerms = [
        # Select on any subnet that has the "karpenter.sh/discovery: ${CLUSTER_NAME}"
        # AND the "environment: test" tag OR any subnet with ID "subnet-09fa4a0a8f233a921"
        {
          tags = {
            "karpenter.sh/discovery" = var.eks_cluster_name
          }
        },
      ]

      # Required, discovers security groups to attach to instances
      # Each term in the array of securityGroupSelectorTerms is ORed together
      # Within a single term, all conditions are ANDed

      securityGroupSelectorTerms = [
        # Select on any security group that has both the "karpenter.sh/discovery: ${CLUSTER_NAME}" tag
        # AND the "environment: test" tag OR any security group with the "my-security-group" name
        # OR any security group with ID "sg-063d7acfb4b06c82c"
        {
          tags = {
            "karpenter.sh/discovery" = var.eks_cluster_name
          }
        }
      ]

      # Optional, IAM role to use for the node identity.
      # The "role" field is immutable after EC2NodeClass creation. This may change in the
      # future, but this restriction is currently in place today to ensure that Karpenter
      # avoids leaking managed instance profiles in your account.
      # Must specify one of "role" or "instanceProfile" for Karpenter to launch nodes
      # role = "KarpenterNodeRole-${CLUSTER_NAME}"

      # Optional, IAM instance profile to use for the node identity.
      # Must specify one of "role" or "instanceProfile" for Karpenter to launch nodes
      role = var.eks_node_role_name

      # Each term in the array of amiSelectorTerms is ORed together
      # Within a single term, all conditions are ANDed
      amiSelectorTerms = lookup(each.value, "ami_selector_terms", [{ alias = "al2023@latest" }])

      # Optional, use instance-store volumes for node ephemeral-storage
      # instanceStorePolicy = "RAID0"

      # Optional, overrides autogenerated userdata with a merge semantic
      userData = each.value.user_data

      # Optional, propagates tags to underlying EC2 resources
      tags = merge(var.tags, tomap({ Name = "karpenter/${each.key}" }))

      # Optional, configures storage devices for the instance
      blockDeviceMappings = [
        {
          deviceName = "/dev/xvda"
          ebs = {
            encrypted           = true
            volumeSize          = lookup(each.value, "volume_size", "80Gi")
            volumeType          = "gp3"
            deleteOnTermination = true
          }
        }
      ]

      # Optional, configures detailed monitoring for the instance
      # detailedMonitoring = true

    }
  }
  field_manager {
    force_conflicts = true
  }
  timeouts {
    create = "1m"
    update = "1m"
    delete = "1m"
  }
}
