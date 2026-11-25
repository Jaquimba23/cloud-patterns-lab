output "paginas_de_prueba" {
  description = "Abrir cada URL en el navegador (esperar 2-3 minutos tras el apply)"
  value       = { for k, i in aws_instance.this : k => "http://${i.public_ip}" }
}
