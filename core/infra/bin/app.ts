import { App } from 'aws-cdk-lib';
import { AppStack } from '../lib/app-stack.js';

const required = (name: string) => {
  const value = process.env[name];
  if (!value) throw new Error(`Missing env var ${name} (core/infra/.env)`);
  return value;
};

new AppStack(new App(), 'ChipaxChallengeApp', {
  env: { account: required('AWS_ACCOUNT_ID'), region: required('AWS_REGION') },
  domain: required('DOMAIN'),
  certArn: required('CERT_ARN'),
  lambdaCodePath: new URL('../../dist', import.meta.url).pathname,
});
