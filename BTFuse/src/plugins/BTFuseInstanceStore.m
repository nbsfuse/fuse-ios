/*
Copyright 2023-2024 Breautek

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
#import <BTFuse/BTFuseInstanceStore.h>

@implementation BTFuseInstanceStore {
    NSMutableDictionary* $store;
}

- (instancetype) init:(BTFuseContext*) context {
    self = [super init:context];
    
    $store = [[NSMutableDictionary alloc] init];
    
    [$store setObject: @"testData" forKey: @"testKey"];
    
    return self;
}

- (NSString*) getID {
    return @"FuseInstanceStore";
}

- (void) encodeRestorableStateWithCoder:(NSCoder*) coder {
    @synchronized ($store) {
        [coder encodeObject: $store forKey: @"FuseInstanceStore"];
    }
}

- (void) decodeRestorableStateWithCoder:(NSCoder*) coder {
    @synchronized ($store) {
        $store = [coder decodeObjectForKey: @"FuseInstanceStore"];
    }
}

- (void) initHandles {
    __weak BTFuseInstanceStore* weakSelf = self;
    
    [self attachHandler:@"/set" callback:^(BTFuseAPIPacket* packet, BTFuseAPIResponse* response) {
        BTFuseInstanceStore* strongSelf = weakSelf;
        
        NSString* data = [packet readAsString];
        @synchronized (strongSelf->$store) {
            [strongSelf->$store setObject: data forKey: @"data"];
        }
    }];
    
    [self attachHandler:@"/get" callback:^(BTFuseAPIPacket* packet, BTFuseAPIResponse* response) {
        BTFuseInstanceStore* strongSelf = weakSelf;
        
        NSString* data = nil;
        @synchronized (strongSelf->$store) {
            data = [strongSelf->$store objectForKey: @"data"];
        }
        
        if (data != nil) {
            [response sendString: data];
        }
        else {
            [response sendNoContent];
        }
    }];
}

@end
