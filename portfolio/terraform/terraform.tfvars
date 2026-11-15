location = "uksouth"
hostname = "portfolio.dev.michaelalinks.com"

dns_zone = {
  name                = "dev.michaelalinks.com"
  resource_group_name = "kubernetes"
}

registry = {
  name                = "localacrk8s"
  resource_group_name = "kubernetes"
}

cluster = {
  resource_group_name = "rg-management"
  name                = "aks-management"
}
