host = {
  environment    = "portfolio-hosting"
  resource_group = "rg-portfolio-hosting"
}

registry = {
  name           = "localacrk8s"
  resource_group = "kubernetes"
}

cluster = {
  name           = "aks-management"
  resource_group = "rg-management"
}
