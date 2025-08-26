#!/bin/bash
clear
# Actualizar y instalar paquetes necesarios
function set_env(){
   echo "Actualizando repositorios..."
   apt update > /dev/null 2>&1
   echo "Actualizando paquetes de sistema..."
   apt upgrade -y > /dev/null 2>&1
   echo "Instalando paquetes necesarios..."
   DEBIAN_FRONTEND=noninteractive apt install docker.io pv screen -y > /dev/null 2>&1
}

# Descargar imágenes de Docker
function download(){
   echo "Descargando Oracle21c..."
   docker pull container-registry.oracle.com/database/express:21.3.0-xe > /dev/null 2>&1
   echo "Descargando Oracle APEX..."
   docker pull container-registry.oracle.com/database/ords:22.4.0 > /dev/null 2>&1
}

# Configurar directorios y archivos de configuración
function set_config(){
   echo "Configurando instalacion..."
   mkdir -p ords_secrets ords_config  > /dev/null 2>&1
   chmod 777 ords_secrets ords_config > /dev/null 2>&1
   echo 'CONN_STRING=sys/ZJNl987P8A@172.17.0.2:1521/xepdb1' > ords_secrets/conn_string.txt
   echo 'oracle.ords.allowedOrigins=*' > ords_config/ords_params.properties
   echo 'oracle.ords.restful.enabled=true' >> ords_config/ords_params.properties
   echo 'oracle.ords.restful.allowedOrigins=*' >> ords_config/ords_params.properties

   # Crear y habilitar el servicio para Oracle21
   cat <<EOL > /etc/systemd/system/oracle21.service
[Unit]
Description=Start Oracle21
After=network.target docker.service
Requires=docker.service

[Service]
ExecStart=/usr/bin/docker start oracle21
ExecStop=/usr/bin/docker stop oracle21
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOL

   # Crear y habilitar el servicio para Apex
   cat <<EOL > /etc/systemd/system/apex.service
[Unit]
Description=Start Apex
After=network.target docker.service
Requires=docker.service

[Service]
ExecStart=/usr/bin/docker start apex
ExecStop=/usr/bin/docker stop apex
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOL

   systemctl daemon-reload
   systemctl enable oracle21
   systemctl enable apex
}



# Preparar entorno y configuraciones previas
set_env
download
set_config

# Inicializar Oracle Database y Apex
clear
echo "Inicializando Oracle Database..."
docker run -d --name oracle21 -p 1521:1521 -p 5500:5500 -e ORACLE_PWD=ZJNl987P8A container-registry.oracle.com/database/express:21.3.0-xe
echo "Esperando para instalar APEX..."
sleep 60
echo "Oracle Database inicializada y lista. Comenzando instalación de APEX y Servicios REST..."
sleep 3
docker run -d --name apex -e ORDS_PUBLIC_USER_ACCESSIBLE=true -e "ords.allowedOrigins=*" -e "ords.restful.enabled=true" -e "ords.restful.allowedOrigins=*" -v "$(pwd)"/ords_secrets/:/opt/oracle/variables -v "$(pwd)"/ords_config/:/etc/ords/config/ -p 8181:8181 container-registry.oracle.com/database/ords:22.4.0
sleep 30
# Función para verificar el log del contenedor
function check_log_for_success() {
  local container_name="apex"
  local log_file="/tmp/install_container.log"
  docker exec -i apex tail /tmp/install_container.log
  while true; do
    # Ejecutar el comando y capturar la salida
    log_output=$(docker exec -i "$container_name" tail -n 23 "$log_file")
    
    # Verificar el inicio y el fin del resultado
    if [[ "$log_output" == *"...set_appun.sql"* && "$log_output" == *"Version 21.3.0.0.0"* ]]; then
      clear
      echo "Finalizando"
      sleep 1
      clear
      echo "Finalizando."
      sleep 1
      clear
      echo "Finalizando.."
      sleep 1
      clear
      echo "Finalizando..."
      sleep 1
      clear
      echo "Finalizando...."
      sleep 1
      clear      
      break
    else
      clear
      echo "Instalación en curso    - $(date)"
      echo ""
      echo "$(docker exec -i apex tail -n 5 /tmp/install_container.log)"
      sleep 1
      clear
      echo "Instalación en curso.   - $(date)"
      echo ""
      echo "$(docker exec -i apex tail -n 5 /tmp/install_container.log)"
      sleep 1
      clear
      echo "Instalación en curso..  - $(date)"
      echo ""
      echo "$(docker exec -i apex tail -n 5 /tmp/install_container.log)"
      sleep 1
      clear
      echo "Instalación en curso... - $(date)"
      echo ""
      echo "$(docker exec -i apex tail -n 5 /tmp/install_container.log)"
      sleep 1

      # docker exec -i apex tail -n 23 /tmp/install_container.log
      #sleep 5
    fi
  done
}

# Verificar el log del contenedor
check_log_for_success

clear
# Mostrar información final
echo "Oracle Application Express ha sido instalado con éxito y los servicios REST han sido habilitados"
echo ""
echo "La instancia ya está disponible según los siguientes datos:"
echo ""
echo "URL:       http://$(hostname -I | awk '{print $1}'):8181/ords"
echo "WORKSPACE: INTERNAL"
echo "USER:      ADMIN"
echo "PASSWORD:  Welcome_1"
echo ""
echo "La conexión a la base de Datos es la siguiente:"
echo ""
echo "Host: $(hostname -I | awk '{print $1}')"
echo "Port: 1521"
echo "Rol: SYSDBA"
echo "User: sys"
echo "Pass: ZJNl987P8A"
echo "Service Name: xepdb1"
echo ""
echo "by AlexRasen ;)"
