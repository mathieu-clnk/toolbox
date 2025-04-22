const fs = require('fs');
const amqp = require('amqplib');

// setup queue name
const queueName = 'QUEUE_NAME';

/**
 * consume the message
 */
async function consume() {
  // setup connection to RabbitMQ
  const connection = await amqp.connect(...getConnectionOptions());
  // setup channel
  const channel = await connection.createChannel();
  // make sure the queue created
  await channel.assertQueue(queueName, {
    durable: true,
    arguments: {
      'x-message-ttl': 3600000,
      'x-dead-letter-exchange': 'dead-letter'
    }
  });
  console.log(" [*] Waiting for messages in %s. To exit press CTRL+C", queueName);
  // setup consume
  channel.consume(queueName, function (message) {
    // just print the message in the console
    console.log("[%s] Received with id (%s) message: %s", message.properties.correlationId, message.properties.messageId, message.content.toString());
    // ack manually
    channel.ack(message);
  }, {
    // we use ack manually
    noAck: false,
  });
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

consume();