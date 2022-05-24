# Python environment
FROM continuumio/miniconda3 as build

RUN apt-get update && \
    apt-get install -y build-essential csh automake && \
    conda install -c conda-forge conda-pack mamba

COPY environments/env.yml .
RUN mamba env create -f env.yml -n venv && \
    rm env.yml && \
    conda-pack -n venv -o /tmp/env.tar && \
    mkdir /venv &&  \
    cd /venv && \
    tar xf /tmp/env.tar && \
    rm /tmp/env.tar && \
    /venv/bin/conda-unpack && \
    conda clean -afy && \
    find /opt/conda/ -follow -type f -name '*.a' -delete && \
    find /opt/conda/ -follow -type f -name '*.pyc' -delete && \
    find /opt/conda/ -follow -type f -name '*.js.map' -delete && \
    conda env remove -n venv

# Merlin tools
COPY mrln_et/tools tools
RUN cd tools && \
    sh compile_tools.sh

# Deploy
FROM nvidia/cuda:11.4.1-cudnn8-devel-ubuntu20.04

RUN apt-get update && \
    apt-get install -y espeak-ng sox build-essential lsb-release

WORKDIR /app
#VOLUME /app/voices
    
VOLUME /tmp

RUN adduser --disabled-password --gecos "app" app && \
    chown -R app:app /app
USER app
ENV USER=app

COPY --from=build --chown=app:app /venv /venv
ENV PATH="/venv/bin:${PATH}"
RUN python -c "import nltk; nltk.download(\"punkt\")";

COPY --chown=app:app . .
#! Fix me

# Merlin tools
#COPY --chown=app:app mrln_et mrln_et
RUN rm -rf mrln_et/tools

#COPY --chown=app:app mrln_et/src mrln_et/
COPY --from=build --chown=app:app /tools mrln_et/tools

RUN mkdir logs
#COPY --chown=app:app tts_preprocess_et/ tts_preprocess_et/
#COPY --chown=app:app settings.py tts_worker.py ./
#COPY --chown=app:app mrln_et/src/ mrln_et/src/
#COPY --chown=app:app mrln_et/conf/ mrln_et/conf/
#COPY --chown=app:app mrln_et/run.py mrln_et/submit.sh mrln_et/synth.sh mrln_et/

ENV PYTHONIOENCODING=utf8
ENV LANG=C.UTF-8
RUN echo "python tts_worker.py --worker \$WORKER_NAME" > entrypoint.sh

ENTRYPOINT ["bash", "entrypoint.sh"]
