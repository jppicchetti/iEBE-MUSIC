## Using iEBE-MUSIC via Docker

Docker is a software tool that allows one to deploy an application in a portable environment. A docker "image" can be created for the application, allowing any user to run a docker "container" from this image.

### 1. Build a new Docker image
We can build a docker image for the iEBE-MUSIC package using the following command,

    docker build -t iebe-music .

### 2. Run iEBE-MUSIC
The docker container has ready compiled all the software packages for iEBE-MUSIC.

	docker run -it --name myiEBE chunshen1987/iebe-music:latest

### 3. To delete all the Docker images in your laptop

	docker system prune -a

## Using iEBE-MUSIC via Singularity

Use the following command to create a singularity image (sif) from the
docker image,

    singularity pull  docker://chunshen1987/iebe-music:dev

To run the singularity image, `singularity run iebe-music_dev.sif`

## Updating an existing local image

`Dockerfile.update-only` reuses a previously built Docker image, refreshes the
repository to `joao/clean-final`, and rebuilds the hadronic afterburner toolkit.
The source revision is passed as a Docker build argument so Docker cannot reuse
the old source/build layer accidentally.

The base image must already exist as a local Docker tag. Build and verify an
updated Docker image and Singularity image with:

```bash
./docker/build_update_image.sh iebe-music-joao-oct27v2 iebe-music-joao-oct27v2.sif
```

Optional environment variables:

```bash
BASE_IMAGE=iebe-music-joao-sep06v1:latest
GIT_REF=origin/joao/clean-final
```

The script fails if the base tag is missing, the native toolkit does not
compile, or the resulting executable does not contain the compact SPVN code.
