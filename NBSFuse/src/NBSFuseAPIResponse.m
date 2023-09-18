
/*
Copyright 2023 Norman Breau

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

#import <Foundation/Foundation.h>
#import <NBSFuse/NBSFuseAPIResponse.h>
#include <sys/socket.h>

@implementation NBSFuseAPIResponse

- (instancetype) init:(int) client {
    self = [super init];
    
    $client = client;
    $hasSentHeaders = false;
    $status = NBSFuseAPIResponseStatusOk;
    $contentLength = 0;
    $contentType = @"application/octet-stream";
    
    return self;
}

- (void)setStatus:(NSUInteger)status {
    $status = status;
}

- (void) setContentType:(NSString*)contentType {
    $contentType = contentType;
}

- (void) setContentLength:(NSUInteger)length {
    $contentLength = length;
}

- (void) didFinishHeaders {
    $hasSentHeaders = true;
    
    NSMutableString* headers = [[NSMutableString alloc] initWithString:@"HTTP/1.1"];
    [headers appendString:[NSString stringWithFormat:@" %lu %@\r\n", $status, [self getStatusText:$status]]];
    [headers appendString:[NSString stringWithFormat:@"Access-Control-Allow-Origin: %@\r\n", @"nbsfuse://localhost"]];
    [headers appendString:[NSString stringWithFormat:@"Access-Control-Allow-Headers: %@\r\n", @"*"]];
    [headers appendString:[NSString stringWithFormat:@"Cache-Control: %@\r\n", @"no-cache"]];
    [headers appendString:[NSString stringWithFormat:@"Content-Type: %@\r\n", $contentType]];
    [headers appendString:[NSString stringWithFormat:@"Content-Length: %lu\r\n", $contentLength]];
    [headers appendString:@"\r\n"];
    
    const char* headersBytes = [headers UTF8String];
    size_t headersLength = strlen(headersBytes);
    ssize_t bytesWritten = write($client, headersBytes, headersLength);
    
    if (bytesWritten < 0) {
        NSLog(@"Error writing to the client socket");
        close($client);
    }
}

- (NSString*) getStatusText:(NSUInteger) status {
    switch (status) {
        case NBSFuseAPIResponseStatusOk:
            return @"OK";
        case NBSFuseAPIResponseStatusError:
            return @"Bad Request";
        case NBSFuseAPIResponseStatusInternalError:
            return @"Internal Error";
        default:
            return @"Unknown";
    }
}

- (void) pushData:(NSData *)data {
    if (!$hasSentHeaders) {
        NSLog(@"Cannot send data before headers are sent. Must call finishHeaders first!");
        // TODO: Raise exception somehow
        return;
    }
    
    const void* dataBytes = [data bytes];
    NSUInteger dataLength = [data length];

    ssize_t bytesWritten = write($client, dataBytes, dataLength);
    if (bytesWritten < 0) {
        NSLog(@"Error writing to the client socket");
        close($client);
    }
}

- (void) didFinish {
    shutdown($client, SHUT_RDWR);
}

- (void) didInternalError {
    [self setStatus:NBSFuseAPIResponseStatusInternalError];
    [self setContentType:@"text/plain"];
    NSString* msg = @"Internal Error. See native logs for more details";
    [self setContentLength:[msg length]];
    [self didFinishHeaders];
    [self pushData: [msg dataUsingEncoding:NSUTF8StringEncoding]];
    [self didFinish];
}

- (void) finishHeaders:(NSUInteger) status withContentType:(NSString*) contentType withContentLength:(NSUInteger) contentLength {
    [self setStatus:status];
    [self setContentType:contentType];
    [self setContentLength:contentLength];
    [self didFinishHeaders];
}

- (void) sendData:(NSData*) data {
    [self finishHeaders:NBSFuseAPIResponseStatusOk withContentType:@"application/octet-stream" withContentLength: data.length];
    [self pushData: data];
    [self didFinish];
}

- (void) sendData:(NSData*) data withType:(NSString*) type {
    [self finishHeaders:NBSFuseAPIResponseStatusOk withContentType:type withContentLength: data.length];
    [self pushData: data];
    [self didFinish];
}

- (void) sendJSON:(NSDictionary*) data {
    NSError* serializationError;
    NSData* serialized = [NSJSONSerialization dataWithJSONObject:data options:NSJSONWritingPrettyPrinted error:&serializationError];
    if (serializationError != nil) {
        NSLog(@"Error domain: %@", serializationError.domain);
        NSLog(@"Error code: %ld", (long)serializationError.code);
        NSLog(@"Error description: %@", serializationError.localizedDescription);
        
        if (serializationError.localizedFailureReason) {
            NSLog(@"Failure reason: %@", serializationError.localizedFailureReason);
        }
        
        if (serializationError.localizedRecoverySuggestion) {
            NSLog(@"Recovery suggestion: %@", serializationError.localizedRecoverySuggestion);
        }
        
        NSLog(@"Error user info: %@", serializationError.userInfo);
        [self didInternalError];
        return;
    }
    [self finishHeaders:NBSFuseAPIResponseStatusOk withContentType:@"application/json" withContentLength: serialized.length];
    [self pushData:serialized];
    [self didFinish];
}

- (void) sendString:(NSString*) data {
    [self finishHeaders:NBSFuseAPIResponseStatusOk withContentType:@"text/plain" withContentLength:[data length]];
    [self pushData: [data dataUsingEncoding:NSUTF8StringEncoding]];
    [self didFinish];
}

- (void) sendNoContent {
    [self finishHeaders:NBSFuseAPIResponseStatusOk withContentType:@"text/plain" withContentLength:0];
    [self didFinish];
}

- (void) sendError:(NBSFuseError*) error {
    NSError* serializationError = nil;
    NSString* data = [error serialize:serializationError];
    if (serializationError != nil) {
        NSLog(@"Error domain: %@", serializationError.domain);
        NSLog(@"Error code: %ld", (long)serializationError.code);
        NSLog(@"Error description: %@", serializationError.localizedDescription);
        
        if (serializationError.localizedFailureReason) {
            NSLog(@"Failure reason: %@", serializationError.localizedFailureReason);
        }
        
        if (serializationError.localizedRecoverySuggestion) {
            NSLog(@"Recovery suggestion: %@", serializationError.localizedRecoverySuggestion);
        }
        
        NSLog(@"Error user info: %@", serializationError.userInfo);
        [self didInternalError];
        return;
    }
    
    [self finishHeaders:NBSFuseAPIResponseStatusError withContentType:@"application/json" withContentLength:[data length]];
    [self pushData: [data dataUsingEncoding:NSUTF8StringEncoding]];
    [self didFinish];
}

@end
