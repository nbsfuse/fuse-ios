
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

#ifndef NBSFuseRuntime_h
#define NBSFuseRuntime_h

#import <Foundation/Foundation.h>
#import <NBSFuse/NBSFusePlugin.h>

@interface NBSFuseRuntime : NBSFusePlugin

@property (atomic, strong) NSMutableArray* $pauseHandlers;
@property (atomic, strong) NSMutableArray* $resumeHandlers;

- (NSString*) getID;

- (NSDictionary*) getInfo;

- (void) onPause;
- (void) onResume;

@end

#endif /* NBSFuseRuntime_h */