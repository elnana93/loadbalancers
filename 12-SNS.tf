
# ADD PagerDuty Later !!!!!!! (For experience)
#change the sns name later
resource "aws_sns_topic" "e5_alerts" {
  name = "db-connection-failure-alerts"
}

resource "aws_sns_topic_subscription" "sns_email" {
  topic_arn = aws_sns_topic.e5_alerts.arn
  protocol  = "email"
  endpoint  = "e5techmanagement@gmail.com"
}
