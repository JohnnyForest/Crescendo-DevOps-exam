resource "aws_instance" "web" {
  ami                    = var.ami
  instance_type          = var.instance_type
  subnet_id             = aws_subnet.public_1.id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  key_name               = var.key_name

  user_data = <<-EOF
              #!/bin/bash
              sudo yum update -y

              #java
              sudo yum install -y java-11-amazon-corretto

              #nginx
              sudo amazon-linux-extras enable nginx1
              sudo yum install -y nginx
              sudo systemctl enable nginx

              #magnolia
              cd /opt
              sudo curl -O https://files.magnolia-cms.com/travel-demo-webapp-6.3.4-tomcat-bundle.zip
              sudo yum install -y unzip
              sudo unzip magnolia-community-tomcat-bundle.zip
              sudo mv magnolia-community-tomcat-bundle magnolia

              cd /opt/magnolia/apache-tomcat/bin
              sudo ./startup.sh

              echo "[Unit]
              Description=Magnolia CMS
              After=network.target

              [Service]
              Type=simple
              ExecStart=/opt/magnolia/apache-tomcat/bin/startup.sh
              ExecStop=/opt/magnolia/apache-tomcat/bin/shutdown.sh
              Restart=always
              User=root

              [Install]
              WantedBy=multi-user.target" | sudo tee /etc/systemd/system/magnolia.service

              sudo systemctl daemon-reload
              sudo systemctl enable magnolia
              sudo systemctl start magnolia

              #reverse proxy
              sudo bash -c 'cat > /etc/nginx/conf.d/magnolia.conf <<EOL
              server {
                  listen 80;
                  server_name _;
                  location / {
                      proxy_pass http://127.0.0.1:8080;
                      proxy_set_header Host \$host;
                      proxy_set_header X-Real-IP \$remote_addr;
                      proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
                      proxy_set_header X-Forwarded-Proto \$scheme;
                  }
              }
              EOL'

              sudo systemctl restart nginx

              #https
              sudo mkdir -p /etc/nginx/ssl
              #self signed cert, take note, i havent configured any city/domain specifics for this exam
              sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/nginx/ssl/magnolia.key -out /etc/nginx/ssl/magnolia.crt -subj "/C=US/ST=State/L=City/O=Company/OU=IT/CN=your-domain.com"

              sudo bash -c 'cat > /etc/nginx/conf.d/magnolia-ssl.conf <<EOL
              server {
                  listen 443 ssl;
                  server_name _;
                  ssl_certificate /etc/nginx/ssl/magnolia.crt;
                  ssl_certificate_key /etc/nginx/ssl/magnolia.key;

                  location / {
                      proxy_pass http://127.0.0.1:8080;
                      proxy_set_header Host \$host;
                      proxy_set_header X-Real-IP \$remote_addr;
                      proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
                      proxy_set_header X-Forwarded-Proto \$scheme;
                  }
              }
              EOL'

              sudo systemctl restart nginx
              EOF

  tags = {
    Name = "MagnoliaServer"
  }
}
