FROM continuumio/miniconda3 as build

# Python environment
RUN apt-get update && \
    apt-get install -y build-essential && \
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
RUN apt-get install -y build-essential csh automake
COPY mrln_et/tools tools
RUN cd tools && \
    sh compile_tools.sh

# Prod
FROM nvidia/cuda:11.4.1-base-ubuntu20.04

RUN apt-get update && \
    apt-get install -y espeak-ng sox build-essential

ENV PYTHONIOENCODING=utf-8
WORKDIR /app
VOLUME /app/models

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

RUN ls && \
    cd mrln_et && \
    ls && \
    ./synth.sh  eki_et_tnu16k in.txt tnu.wav

RUN echo "python tts_worker.py --worker \$WORKER_NAME" > entrypoint.sh

ENTRYPOINT ["bash", "entrypoint.sh"]
