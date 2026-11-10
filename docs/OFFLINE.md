# Downloading while you have fast/free Internet

The project deliberately **does not commit** Docker image layers, pretrained
weights, Gazebo assets, robot datasets, or cloned third-party sources into Git.
They may be many gigabytes, may be licensed separately, and are not useful
inside normal Git history.

From the project root, after Docker + NVIDIA Container Toolkit are configured:

```bash
bash scripts/prepare.sh
df -h .
bash scripts/preload.sh --all
```

This builds the base and three optional images, checks out curated upstream
robotics source references and Gazebo's legacy model database, and downloads a
compact set of vision, depth-estimation and embedding models. Cached model
weights live in the `ml_cache` Docker volume; other downloads live in
`./downloads` on your host. Clone histories are shallow to save disk;
working source files are present.

Additional, larger weights:

```bash
bash scripts/preload.sh --extended-models
```

The optional Isaac Sim image is **not compatible with RTX 2060 6 GB**. If you
will transfer it to a machine with a supported NVIDIA GPU and have reviewed
NVIDIA's license, you may separately download it:

```bash
bash scripts/preload.sh --isaac-image
```

Verify your downloads and images before going offline:

```bash
docker image ls
docker volume ls
du -sh downloads
docker compose -f compose.yaml -f compose.stacks.yaml --profile ml run --rm --no-deps -T ml \
  python -c 'import torch, gymnasium; print(torch.__version__)'
```

For **cross-machine** offline use, Docker image and volume caches do not move
with a Git clone. Export them to external storage deliberately using
`docker save` and a backup of the relevant named Docker volumes. Be mindful
of available disk space: exporting images duplicates significant data.
Download/copy datasets and pretrained weights only where permitted by their
licenses. Some Hugging Face models require authentication or terms acceptance.

Downloading everything possible on the Internet is neither finite nor useful;
the curated set covers common ROS, mobility, manipulation, fleet, vision and
RL workflows while remaining maintainable. Add project-specific datasets and
models once you select actual robots and tasks.
