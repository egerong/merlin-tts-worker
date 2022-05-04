# Estonian Text-to-Speech

This repository contains Estonian multi-speaker neural text-to-speech synthesis workers that process requests from 
RabbitMQ.

The project is developed by the [Estonian Language Institute](https://www.eki.ee) and is based on work by the [NLP research group](https://tartunlp.ai) at the [Universty of Tartu](https://ut.ee).
Speech synthesis can also be tested in our [web demo](https://www.neurokone.ee/).

## Models

[The releases section](https://github.com/TartuNLP/text-to-speech-worker/releases) contains the model files or their 
download instructions. If a release does not specify the model information, the model from the previous release can 
be used. We advise always using the latest available version to ensure best model quality and code compatibility.

## Setup

The TTS worker can be deployed using the docker image published alongside the repository. Each image version correlates 
to a specific release. The required model file(s) are excluded from the image to reduce the image size and should be
downloaded from the releases section and their directory should be attached to the volume `/app/models`.

Logs are stored in `/app/logs/` and logging configuration is loaded from `/app/config/logging.ini`. Service 
configuration from `/app/config/config.yaml` files.

The RabbitMQ connection parameters are set with environment variables, exchange and queue names are dependent on the 
`service` and `routing_key` (speaker name) values in `config.yaml`. The setup can be tested with the following sample
`docker-compose.yml` configuration where `WORKER_NAME` matches the worker name in your config file. One worker should 
be added for each model.

```
version: '3'
services:
  rabbitmq:
    image: 'rabbitmq:3.6-alpine'
    environment:
      - RABBITMQ_DEFAULT_USER=${RABBITMQ_USER}
      - RABBITMQ_DEFAULT_PASS=${RABBITMQ_PASS}
  tts_api:
    image: ghcr.io/tartunlp/text-to-speech-api:latest
    environment:
      - MQ_HOST=rabbitmq
      - MQ_PORT=5672
      - MQ_USERNAME=${RABBITMQ_USER}
      - MQ_PASSWORD=${RABBITMQ_PASS}
      - GUNICORN_WORKERS=8
    ports:
      - '5000:5000'
    depends_on:
      - rabbitmq
  tts_worker_mari:
    image: ghcr.io/tartunlp/text-to-speech-worker:latest
    environment:
      - WORKER_NAME=mari
      - MQ_HOST=rabbitmq
      - MQ_PORT=5672
      - MQ_USERNAME=${RABBITMQ_USER}
      - MQ_PASSWORD=${RABBITMQ_PASS}
    volumes:
      - ./models:/app/models
    depends_on:
      - rabbitmq
```

### Manual setup

The following steps have been tested on Ubuntu. The code is both CPU and GPU compatible (CUDA required), but the 
`environment.gpu.yml` file should be used for a GPU installation.

- Make sure you have the following prerequisites installed:
    - Conda (see https://docs.conda.io/projects/conda/en/latest/user-guide/install/linux.html)
    - GNU Compiler Collection (`sudo apt install build-essential`)

- Clone this repository with submodules
- Create and activate a Conda environment with all dependencies:

```
conda env create -f environments/environment.yml -n tts
conda activate tts
python -c 'import nltk; nltk.download("punkt"); nltk.download("cmudict")'
```

- Download the models from the [releases section](https://github.com/TartuNLP/text-to-speech-worker/releases) and 
  place inside the `models/` directory.

- Check the configuration files and change any defaults as needed. Make sure that the `checkpoint` parameters in
  `config/config.yaml` points to the model filse you just downloaded. By default, logs will be stored in the 
  `logs/` directory which is specified in the `config/logging.ini` file.
- Specify RabbitMQ connection parameters with environment variables or in a `config/.env` file as illustrated in the 
  `config/sample.env`.

Run the worker with where `WORKER_NAME` matches the model name in your config file:
```
python tts_worker.py --log-config config/logging.ini --config config/config.yaml --worker $WORKER_NAME
```
