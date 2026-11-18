import { App } from 'aws-cdk-lib';
import { Template } from 'aws-cdk-lib/assertions';
import { describe, expect, it } from 'vitest';
import { AppStack } from './app-stack.js';

const stack = new AppStack(new App(), 'Test', {
  env: { account: '123456789012', region: 'us-east-1' },
  domain: 'challenge.woku.uk',
  certArn: 'arn:aws:acm:us-east-1:123456789012:certificate/abc',
  lambdaCodePath: new URL('./fixtures', import.meta.url).pathname,
});
const template = Template.fromStack(stack);

describe('AppStack', () => {
  it('serves the domain through CloudFront with the certificate', () => {
    template.hasResourceProperties('AWS::CloudFront::Distribution', {
      DistributionConfig: {
        Aliases: ['challenge.woku.uk'],
        ViewerCertificate: { AcmCertificateArn: 'arn:aws:acm:us-east-1:123456789012:certificate/abc' },
      },
    });
  });

  it('keeps the front bucket private', () => {
    template.hasResourceProperties('AWS::S3::Bucket', {
      PublicAccessBlockConfiguration: { BlockPublicAcls: true, RestrictPublicBuckets: true },
    });
  });

  it('exposes the API as a Lambda function URL on arm64', () => {
    template.hasResourceProperties('AWS::Lambda::Function', { Architectures: ['arm64'] });
    template.resourceCountIs('AWS::Lambda::Url', 1);
  });

  it('routes /api/* to the Lambda origin', () => {
    const dist = Object.values(template.findResources('AWS::CloudFront::Distribution'))[0] as {
      Properties: { DistributionConfig: { CacheBehaviors: { PathPattern: string }[] } };
    };
    expect(dist.Properties.DistributionConfig.CacheBehaviors.map((b) => b.PathPattern)).toContain('/api/*');
  });
});
