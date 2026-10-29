output "app_url" {
  value       = "http://${aws_instance.lab.public_ip}:8080"
  description = "URL de la app del lab"
}

output "attack_command" {
  value       = "./attack/attacker.sh http://${aws_instance.lab.public_ip}:8080"
  description = "Comando para lanzar el ataque en vivo"
}

output "ssh" {
  value = "ssh ubuntu@${aws_instance.lab.public_ip}"
}
