FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update -o Acquire::Retries=3 && \
    apt-get install -y --no-install-recommends gcc --fix-missing && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Run with hot reload in development
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]
