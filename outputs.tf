output "cluster_id" {
  value = "${aws_ecs_cluster.cluster.id}"
}

output "autoscaling_group" {
#  value = "${map(
#    "id", "${aws_autoscaling_group.ecs.id}",
#    "name", "${aws_autoscaling_group.ecs.name}",
#    "arn", "${aws_autoscaling_group.ecs.arn}",
#  )}"
  value = {
    id = "${aws_autoscaling_group.ecs.id}"
    name = "${aws_autoscaling_group.ecs.name}"
    arn = "${aws_autoscaling_group.ecs.arn}"
  }
}
