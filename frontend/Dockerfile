FROM node:20-alpine

WORKDIR /app

# Install dependencies first (cached layer)
COPY package.json ./
RUN npm install

# Copy source (volume-overridden in dev)
COPY . .

EXPOSE 3000

CMD ["npm", "run", "dev"]
