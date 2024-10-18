ARG BASE_IMAGE=python:3.10-slim-buster
FROM $BASE_IMAGE

# Install deps
RUN apt-get update && apt-get install -y \ 
    curl \
    git

RUN pip install --upgrade pip && \
    pip install --user pipx && \
    python3 -m pipx ensurepath && \
    pip install flask

# ensure PATH contains pipx
ENV PATH="$PATH:/root/.local/bin"

RUN mkdir /service
WORKDIR /service

# Copy source code and prep the environment
COPY service/singerio_tap_service.py ./

RUN mkdir ./output

# Run the service    
CMD ["python3", "singerio_tap_service.py"]
