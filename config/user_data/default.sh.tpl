#!/bin/bash

echo "--------- PACKAGE UPDATE START ---------"
sudo yum update -y
(crontab -l 2>/dev/null; echo "0 23 * * * yum updateinfo list ; yum update -y") | crontab -
echo "--------- PACKAGE UPDATE END ---------"


echo "--------- USER-DATA COMPLETED AT ---------"
date