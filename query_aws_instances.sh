# This is a query that I am using to find all of my AWS instances running in the Oregon region or `us-west-2`. 
# It can be altered so it displays the output based on the key “User” if you change it from ```[?Key==`Name`]``` to ```[?Key==`User`]```, 
# but I wanted to stick with displaying the name description instead:

# Search using tags. This is an example:
KEY="User"
VALUE="diego.saavedrakloss"
REGION="us-west-2"

aws ec2 describe-instances --region ${REGION} \
  --filters "Name=tag:${KEY},Values=${VALUE}" "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].[Placement.AvailabilityZone, InstanceId, State.Name, InstanceType, PublicIpAddress, Tags[?Key==`Name`]|[0].Value]' \
  --output table

# For additional tags these 2 sites are good:
# https://serverfault.com/questions/778426/aws-ec2-describe-instances-filtering-by-multiple-ec2-tags
# https://github.com/aws/aws-cli/issues/368
