FROM jupyterhub/jupyterhub:latest

# Install required packages
RUN pip install --no-cache-dir \
    dockerspawner \
    psycopg2-binary \
    PyJWT \
    requests \
    bcrypt \
    jupyterhub-idle-culler

# Install Docker client
RUN apt-get update && \
    apt-get install -y docker.io && \
    rm -rf /var/lib/apt/lists/*

# Create jupyterhub directory
RUN mkdir -p /srv/jupyterhub

WORKDIR /srv/jupyterhub

# Copy configuration
COPY jupyterhub_config.py /srv/jupyterhub/

EXPOSE 8000

CMD ["jupyterhub", "-f", "/srv/jupyterhub/jupyterhub_config.py"]