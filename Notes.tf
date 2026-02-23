/* 

to start a ssm session 
aws ssm start-session --region us-west-2 --target i-013342db7df1a0d52

To identify the EC2 Instance

aws ec2 describe-instances \
  --region us-west-2 \
  --instance-ids i-00ca2a9a512e8927a
_________________________________________________

Commands For a Private or Public EC2 Instance:

aws ec2 describe-instances \
  --region us-west-2 \
  --instance-ids i-00ca2a9a512e8927a \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text
__________________________________________________

Prove VPC endpoints exist

aws ec2 describe-vpc-endpoints \
  --filters "Name=vpc-id,Values=vpc-07ae19e090fca752f" \
  --query "VpcEndpoints[].ServiceName"

__________________________________________________

Prove Session Manager path works (no SSH)

  aws ssm describe-instance-information \
  --query "InstanceInformationList[].InstanceId"
___________________________________________________

Prove the instance can read both config stores
Run from SSM session:

  aws ssm get-parameter --name /lab1b/db/host
  aws secretsmanager get-secret-value --secret-id lab/rds/mysql
___________________________________________________
Prove CloudWatch logs delivery path is available via endpoint

  aws logs describe-log-streams \
    --log-group-name "/lab1b/app" \

__________________________________________________

Check target group health (ALB -> EC2 app) and confirm the target is healthy on port 80.

aws elbv2 describe-target-health \
   --target-group-arn arn:aws:elasticloadbalancing:us-west-2:676373376093:targetgroup/e5-tg01/c4ff2c87f66b541f \
   --region us-west-2 \
   --query 'TargetHealthDescriptions[*].[Target.Id,Target.Port,TargetHealth.State,TargetHealth.Reason,TargetHealth.Description]' \
   --output table \
   --no-cli-pager



to start a ssm session 
aws ssm start-session --region us-west-2 --target i-013342db7df1a0d52



0-Auth.tf
        1-VPC.tf
        10-CloudWatch.tf
        11-SSM.tf
        12-SNS.tf
        13-VPCEndpoints.tf
        14-LoadBalancer.tf
        15-Route53.tf
        2-Subnets.tf
        3-Route.tf
        4-SG.tf
        5-EC2.tf
        6-RDS.tf
        7-SecretsManager.tf
        8-Roles.tf
        9-Lambda.tf
        Backend.tf




 */