resource "aws_eks_cluster" "this" {
  name                      = "${var.cluster_name}"
  enabled_cluster_log_types = "${var.cluster_enabled_log_types}"
  role_arn                  = "${local.cluster_iam_role_arn}"
  version                   = "${var.cluster_version}"

  vpc_config {
    security_group_ids      = ["${local.cluster_security_group_id}"]
    subnet_ids              = ["${var.subnets}"]
    endpoint_private_access = "${var.cluster_endpoint_private_access}"
    endpoint_public_access  = "${var.cluster_endpoint_public_access}"
  }

  timeouts {
    create = "${var.cluster_create_timeout}"
    delete = "${var.cluster_delete_timeout}"
  }

  depends_on = [
    "aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy",
    "aws_iam_role_policy_attachment.cluster_AmazonEKSServicePolicy",
  ]
}

resource "aws_security_group" "cluster" {
  count       = "${var.cluster_create_security_group ? 1 : 0}"
  name_prefix = "${var.cluster_name}"
  description = "EKS cluster security group."
  vpc_id      = "${var.vpc_id}"
  tags        = "${merge(var.tags, map("Name", "${var.cluster_name}-eks_cluster_sg"))}"
}

resource "aws_security_group_rule" "cluster_egress_internet" {
  count             = "${var.cluster_create_security_group ? 1 : 0}"
  description       = "Allow cluster egress access to the Internet."
  protocol          = "-1"
  security_group_id = "${aws_security_group.cluster.id}"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 0
  to_port           = 0
  type              = "egress"
}

resource "aws_security_group_rule" "cluster_https_worker_ingress" {
  count                    = "${var.cluster_create_security_group ? 1 : 0}"
  description              = "Allow pods to communicate with the EKS cluster API."
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.cluster.id}"
  source_security_group_id = "${local.worker_security_group_id}"
  from_port                = 443
  to_port                  = 443
  type                     = "ingress"
}

resource "aws_security_group_rule" "cluster_https_worker_ingress1" {
  count                    = "${var.cluster_create_security_group ? 1 : 0}"
  description              = "Allow pods to communicate with the EKS cluster API."
  protocol                 = "tcp"
  cidr_blocks              = "${var.cluster_sg_additional_networks}"
  security_group_id        = "${aws_security_group.cluster.id}"
  from_port                = 443
  to_port                  = 443
  type                     = "ingress"
}

resource "aws_iam_role" "cluster" {
  count                 = "${var.manage_cluster_iam_resources ? 1 : 0}"
  name_prefix           = "${var.cluster_name}"
  assume_role_policy    = "${data.aws_iam_policy_document.cluster_assume_role_policy.json}"
  permissions_boundary  = "${var.permissions_boundary}"
  path                  = "${var.iam_path}"
  force_detach_policies = true
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  count      = "${var.manage_cluster_iam_resources ? 1 : 0}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = "${aws_iam_role.cluster.name}"
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSServicePolicy" {
  count      = "${var.manage_cluster_iam_resources ? 1 : 0}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = "${aws_iam_role.cluster.name}"
}

data "aws_iam_policy_document" "cluster_additional" {
  version = "2012-10-17"

  statement {
    effect    = "Allow"
    resources = ["*"]
    actions   = [
      "ec2:*",
    ]
  }
}

resource "aws_iam_policy" "cluster_additional" {
  name = "${sha1(var.cluster_name)}Clusteradditional"

  policy = "${data.aws_iam_policy_document.cluster_additional.json}"
}

resource "aws_iam_role_policy_attachment" "cluster_additional" {
  role       = "${aws_iam_role.cluster.name}"
  policy_arn = "${aws_iam_policy.cluster_additional.arn}"
}
