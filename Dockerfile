FROM node:20-alpine AS builder
WORKDIR /app
COPY src/ecs-assignment/package.json ./
RUN yarn install
COPY src/ecs-assignment .
RUN yarn build 

FROM node:20-alpine
WORKDIR /app
# serve will not work if build folder is not present
RUN mkdir build 
# used /app/build to acquire the dependency needed for serve command
COPY --from=builder /app/build /app/build 
RUN yarn global add serve
CMD ["serve", "-s", "-n", "build"]
EXPOSE 3000


