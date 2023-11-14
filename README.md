# container-security-book

## Docker

1. `docker build -t book:v1.0.0 .`
2. `docker run -it book:v1.0.0 bash`

## Trivy

### コンテナイメージのスキャン

- trivy image golang:1.21.3-bookworm
- trivy image ubuntu:20.04

### Dockerfile のスキャン

- trivy config .
