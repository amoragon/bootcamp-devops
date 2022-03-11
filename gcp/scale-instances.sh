#!/bin/bash

REGION="europe-west2"
NUM_REQUESTS=100
NUM_USERS=5
MAX_INSTANCES=4

echo -n "Comprobando el numero de instancias en el grupo de autoescalado..."
# Contamos el numero de instancias levantadas
NUM_INSTANCIAS_INICIALES=$(gcloud compute instance-groups list-instances keepcoding-instances-group-apache2 --region=${REGION} --format="value(instance)" | wc -l | tr -ds " " "")
NUM_INSTANCIAS_ACTUALES=${NUM_INSTANCIAS_INICIALES}
echo "${NUM_INSTANCIAS_INICIALES} funcionando actualmente."

# Si estan levantadas el maximo de instancias no
# continuamos con la prueba
if [ ${NUM_INSTANCIAS_INICIALES} -eq ${MAX_INSTANCES} ]
then
    echo "El grupo de instancias ha llegado al máximo. Tiene que desescalar antes de poder probar el grupo de escalado con este script."
fi

# Obtengo la ip de una de las maquinas levantadas
# en caso de que no se llegue al maximo
echo -n "Localizando ip para atacar..."
IP=$(gcloud compute instances list --limit=1 --format="get(networkInterfaces[].accessConfigs[].natIP)" | tr -d "\'[]")
echo ${IP}

# Realizamos peticiones hasta que el numero de instancias varie
echo -n "Comenzando el ataque."
while [[ ${NUM_INSTANCIAS_INICIALES} -eq ${NUM_INSTANCIAS_ACTUALES} ]]; do
    siege -q --concurrent=${NUM_USERS} --reps=${NUM_REQUESTS} "http://${IP}"

    NUM_INSTANCIAS_ACTUALES=$(gcloud compute instance-groups list-instances keepcoding-instances-group-apache2 --region=${REGION} --format="value(instance)" | wc -l | tr -ds " " "")
    echo -n "."
done
echo "El numero de instancias ha aumentado a ${NUM_INSTANCIAS_ACTUALES}"
