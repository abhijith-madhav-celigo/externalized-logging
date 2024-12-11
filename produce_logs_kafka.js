const { Kafka } = require('kafkajs');
const fs = require('fs');
const JSONTemplater = require('json-templater/string');

const kafka = new Kafka({
  clientId: 'kafka-log-producer',
  brokers: ['localhost:9092']
});

const producer = kafka.producer();

const msgMap = { 'customer-1' : './error.json'}

const run = async () => {
  await producer.connect();

  const topic = 'otlp_logs';
  const customer_id = process.argv[2] ? process.argv[2] : 'customer-999999';

  const errorFile = msgMap[customer_id] ? msgMap[customer_id] : './error_otlp_json.json';
  let errorJson = fs.readFileSync(errorFile, 'utf-8');
  errorJson = JSONTemplater(errorJson, { id : customer_id});
  console.log(errorJson)

  const headers = { 'customer-id': customer_id , 'service.name' : 'integrator.io'};

  try {
    await producer.send({
      topic,
      messages: [
        {
          customer_id,
          value : errorJson,
          headers
        }
      ]
    });
    console.log(`Message sent to topic "${topic}"`);
  } catch (error) {
    console.error('Error producing message', error);
  }

  await producer.disconnect();
};

run().catch(console.error);
