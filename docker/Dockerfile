FROM ubuntu:mantic-20230712

# Install minimal Ubuntu system
RUN apt-get update --yes && \
    apt-get upgrade --yes && \
    apt-get install --yes --no-install-recommends \
    ca-certificates \
    locales \
    sudo \
    less \
    python3.11 \
    python3.11-venv && \
    apt-get clean && rm -rf /var/lib/apt/lists/* && \
    echo "en_GB.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen

ENV VENV=/opt/venv
RUN python3 -m venv $VENV 
ENV PATH="$VENV/bin:$PATH"

COPY requirements.txt .
RUN pip install -r requirements.txt


#RUN useradd -m purple
#USER purple
RUN mkdir -p /home/purple
WORKDIR /home/purple

ENTRYPOINT ["jupyter", "lab", "--allow-root", "--ip=0.0.0.0", "--port=8888", "--no-browser", "--LabApp.token=''"]
