#!/bin/bash

handle_error() {
    echo "Error: $1"
    exit 1
}

# Build feature extractor component
build_feature_extractor(){
  arch=$(uname -m)
  platform_option=""
  if [[ "$arch" == "aarch64" || "$arch" == "arm64" ]]; then
    platform_option="--platform linux/x86_64"
  fi

  params=""
  if [ "$cache" == "yes" ]; then
    params=""
  else
    params="--no-cache"
  fi
  docker build $platform_option -t domain-feature-extractor:latest ./pipline/domain_feature_extractor $params

}

build_domain_classifier(){
  arch=$(uname -m)
  platform_option=""
  if [[ "$arch" == "aarch64" || "$arch" == "arm64" ]]; then
    platform_option="--platform linux/x86_64"
  fi

  params=""
  if [ "$cache" == "yes" ]; then
    params=""
  else
    params="--no-cache"
  fi

  docker build $platform_option -t scamagnifier-domain-classifier:latest ./pipline/domain_classifier  $params

}

build_shop_classifier(){
  arch=$(uname -m)
  platform_option=""
  if [[ "$arch" == "aarch64" || "$arch" == "arm64" ]]; then
    platform_option="--platform linux/x86_64"
  fi

  params=""
  if [ "$cache" == "yes" ]; then
    params=""
  else
    params="--no-cache"
  fi

  docker build $platform_option -t scamagnifier-shop-classifier:latest ./pipline/shop_classifier $params

}

build_autocheckout(){
  arch=$(uname -m)
  platform_option=""
  if [[ "$arch" == "aarch64" || "$arch" == "arm64" ]]; then
    platform_option="--platform linux/x86_64"
  fi

  params=""
  if [ "$cache" == "yes" ]; then
    params=""
  else
    params="--no-cache"
  fi

  docker build $platform_option -t autocheck:latest ./pipline/autocheckout  $params

}

build_components() {
    build_feature_extractor || handle_error "Failed to build feature extracotr."
    build_domain_classifier || handle_error "Failed to build domain classifier."
    build_shop_classifier || handle_error "Failed to build shop classifier."
    build_autocheckout || handle_error "Failed to build ac."
}

current_date_time=$(date)

source ./env.sh

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <install|run_pipline>"
    exit 1
fi

json_payload=$(cat <<EOF
{
    "text": "Scamangifier daily pipline started at $current_date_time"
}
EOF
)

case "$1" in
    install)
        echo "Starting installation..."
        mkdir docker-entrypoint-initdb.d
        chmod +x create_mongo_user.sh
        sh create_mongo_user.sh
        mv mongo-init.js ./docker-entrypoint-initdb.d/
        docker compose -f docker-compose-service.yml build

        #if [ ! -f ./.htpasswd ]; then
        #    htpasswd -c ./.htpasswd ${SCAMAGNIFIER_EXT_SELENIUM_USERNAME}
        #else
        #    echo ".htpasswd already exists."
        #fi
        #docker build --no-cache -t autocheck_ext ./autocheckout
        echo "Installation complete."
        ;;
    run_service)
        curl -X POST -H 'Content-type: application/json' --data '{"text":"Scamangifier service is running."}' $WEBHOOK_URL
        docker compose -f docker-compose-service.yml up -d
        ;;
    build)
        build_components
        ;;
    run_pipline)

        curl -X POST -H 'Content-type: application/json' --data "$json_payload" $WEBHOOK_URL

        echo "Running the application..."
        cd $(pwd)/pipline/
        chmod +x $(pwd)/start_pipline.sh
        $(pwd)/pipline/start_pipline.sh --build yes --verbos yes --sel no --mongo no
        cd ..
        echo "Application is now running."
        ;;
    stop)
        docker compose -f docker-compose-service.yml down
        ;;
    ps)
        docker compose -f docker-compose-service.yml ps
        ;;
    pass)
        htpasswd -c ./.htpasswd ${SCAMAGNIFIER_EXT_SELENIUM_USERNAME}
        ;;
    *)
        # Handle invalid arguments
        echo "Invalid argument: $1"
        echo "Usage: $0 <install|run>"
        exit 2
        ;;
esac


