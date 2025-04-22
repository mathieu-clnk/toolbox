const fs = require('fs');
const amqp = require('amqplib');
const { v4: uuidv4 } = require('uuid');

// setup queue name
const queueName = 'QUEUE_NAME';

/**
 * Send message
 */
async function send() {
  // connect to RabbitMQ
  const connection = await amqp.connect(...getConnectionOptions());
  console.log('Connected.')
  //const connection = await amqp.connect(process.env.RABBITMQ_HOST || 'amqp://localhost');
  // create a channel
  const channel = await connection.createChannel();
  console.log('Channel created.')
  // create/update a queue to make sure the queue is exist
  await channel.assertQueue(queueName, {
    durable: true,
    arguments: {
      'x-message-ttl': 3600000,
      'x-dead-letter-exchange': 'dead-letter'
    }
  });
  console.log('Queue asserted.')
  // generate correlation id, basically correlation id used to know if the message is still related with another message
  const correlationId = uuidv4();
  // send 10 messages and generate message id for each messages
  for (let i = 1; i <= 10; i++) {
    const buff = Buffer.from(JSON.stringify({
      test: `Hello World ${i}!!`
    }), 'utf-8');
    console.log('Sending to queue...')
    const result = channel.sendToQueue(queueName, buff, {
      persistent: true,
      messageId: uuidv4(),
      correlationId: correlationId,
    });
    console.log(result);
  }
  // close the channel
  await channel.close();
  // close the connection
  await connection.close();
}

const getConnectionOptions = () => {
  let options = { protocol: 'amqps',port: 5671, vhost: 'VHOST_NAME', heartbeat: 30, username: 'USERNAME', password: 'PASSWORD', hostname: 'HOSTNAME' };

  let socketOptions = { rejectUnauthorized: false, noDelay: true }
  if (options.protocol === 'amqps') {
    socketOptions.cert = fs.readFileSync('PATH_TO_CERT');
    socketOptions.key = fs.readFileSync('PATH_TO_KEY');
    socketOptions.ca = [fs.readFileSync('PATH_TO_CA')];
  }

  return [options, socketOptions];
};

send();
