resource "aws_iam_openid_connect_provider" "oidc_provider" {
  count           = "${var.enable_irsa ? 1 : 0}"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["${var.eks_oidc_root_ca_thumbprint}"]
  url             = "${aws_eks_cluster.example.identity.0.oidc.0.issuer}"
}
