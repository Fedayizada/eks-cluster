
resource "kubernetes_deployment" "coffee" {
  depends_on = [ module.eks_cluster ]
  metadata {
    annotations  = {
     "backstage.io/kubernetes-id" = "kubernetes-component" 
      }
    name = "coffee"
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = "coffee"
      }
    }

    template {
      metadata {
        labels = {
 
          "backstage.io/kubernetes-id" = "kubernetes-component" 
     
          app = "coffee"
        }
      }

      spec {
        affinity {
          node_affinity {
            required_during_scheduling_ignored_during_execution {
              node_selector_term {
                match_expressions {
                  key = "kubernetes.io/arch"
                  operator = "In"
                  values = [ "x86_64","amd64" ]
                }
              }
            }
          }
        }
        container {
          image = "nginxdemos/nginx-hello:plain-text"
          name  = "coffee"
          lifecycle {
            pre_stop {
                exec {
                    command = [
                        "/bin/sh",
                        "-c",
                        "sleep 40",
                      ] 
                  }
              }
            }

          liveness_probe {
              failure_threshold     = 3 
              initial_delay_seconds = 0 
              period_seconds        = 10
              success_threshold     = 1 
              timeout_seconds       = 1 
              http_get {                  
                path   = "/"
                scheme = "HTTP" 
                port  = 8080
                }
            }
          readiness_probe {
              failure_threshold     = 3 
              initial_delay_seconds = 0 
              period_seconds        = 10
              success_threshold     = 1 
              timeout_seconds       = 1 
              http_get {
                path   = "/" 
                port   = 8080
                scheme = "HTTP"
                }
            }
          port {
            container_port = 8080
          }

          resources {
            limits  = {
              cpu    = "0.5"
              memory = "512Mi"
            }
            requests =  {
              cpu    = "250m"
              memory = "50Mi"
            }
          }

        }
      }
    }
  }
}

resource "kubernetes_service" "coffee" {
  metadata {
    name = "coffee"
  }
  spec {
    selector = {
      app = kubernetes_deployment.coffee.spec.0.selector.0.match_labels.app
    }
    port {
      port        = 80
      target_port = 8080
      name        = "http"
      protocol    = "TCP"
    }

    type = "NodePort"
  }
}

resource "kubernetes_ingress_v1" "coffee" {
  metadata {
    name = "coffee"
    annotations = {
      "kubernetes.io/ingress.class" = "alb"
      "alb.ingress.kubernetes.io/scheme" = "internal"
      #"external-dns.alpha.kubernetes.io/alias" = "true"
      "alb.ingress.kubernetes.io/target-type" =  "instance"
      "alb.ingress.kubernetes.io/group.name" = "cafe"
      "alb.ingress.kubernetes.io/certificate-arn" = "arn:aws:acm:us-east-1:004889159502:certificate/b68381cc-f4c0-4aa3-b686-a719a02ee873"
      "alb.ingress.kubernetes.io/ssl-redirect" =  "443"
      "alb.ingress.kubernetes.io/listen-ports" =  jsonencode([{"HTTPS" = 443},{"HTTP" = 80}] )
    }
  }

  spec {
    rule {
      host = "test.techsdemo.com"
      http {
        path {
    
          backend {
            service {
              name = kubernetes_service.coffee.metadata.0.name
              port {
                number =  80
              }
          }
          }

          path = "/coffee"
        }
      path {
    
          backend {
            service {
              name = "default-service"
              port {
                number =  80
              }
          }
          }

          path = "/users"
        }

      }
    }
  }
}
