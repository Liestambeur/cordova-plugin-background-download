/*
 Licensed to the Apache Software Foundation (ASF) under one
 or more contributor license agreements. See the NOTICE file
 distributed with this work for additional information
 regarding copyright ownership. The ASF licenses this file
 to you under the Apache License, Version 2.0 (the
 "License"); you may not use this file except in compliance
 with the License. You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing,
 software distributed under the License is distributed on an
 "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 KIND, either express or implied. See the License for the
 specific language governing permissions and limitations
 under the License.
 */

#import "BackgroundDownload.h"

#import "TWRDownloadManager.h"

@implementation BackgroundDownload {
    bool ignoreNextError;
}

@synthesize session;
@synthesize downloadTask;

- (void)startAsync:(CDVInvokedUrlCommand*)command
{
    //NSLog(@"START ASYNC");
    NSLog(@"START ASYNC for callbackId: %@", command.callbackId);
    self.downloadUri = [command.arguments objectAtIndex:0];
    self.targetFile = [command.arguments objectAtIndex:1];
    NSLog(@"download uri: %@", self.downloadUri);
    NSLog(@"target file: %@", self.targetFile);

    self.callbackId = command.callbackId;
    NSString * cbid = command.callbackId;

    //NSString * dir = [self.targetFile stringByDeletingLastPathComponent];
    //NSString * name = [self.targetFile lastPathComponent];
    //NSLog(@"name: %@", name);
    //NSLog(@"dir: %@", dir);

    [[TWRDownloadManager sharedManager] downloadFileForURL: self.downloadUri toAbsolutePathURL: self.targetFile progressBlock:^(CGFloat p) {
        //NSLog(@"PROGRESS");
        //NSLog(@"PROGRESS for callbackId: %@", self.callbackId);
        NSLog(@"PROGRESS for callbackId: %@", cbid);
    } remainingTime: nil completionBlock: ^(BOOL completed){
        //NSLog(@"COMPLETED: %d", completed);
        //NSLog(@"COMPLETED: %d for callbackId: %@", completed, self.callbackId);
        NSLog(@"COMPLETED: %d for callbackId: %@", completed, cbid);
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        //[self.commandDelegate sendPluginResult:pluginResult callbackId:self.callbackId];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:cbid];
    } enableBackgroundMode:false];

#if 0
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:self.downloadUri]];

    ignoreNextError = NO;

    session = [self backgroundSession];

    [session getTasksWithCompletionHandler:^(NSArray *dataTasks, NSArray *uploadTasks, NSArray *downloadTasks) {
        if (downloadTasks.count > 0) {
            downloadTask = downloadTasks[0];
        } else {
            downloadTask = [session downloadTaskWithRequest:request];
        }
        [downloadTask resume];
    }];
#endif
}

#if 0
- (NSURLSession *)backgroundSession
{
    static NSURLSession *backgroundSession = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"com.cordova.plugin.BackgroundDownload.BackgroundSession"];
        backgroundSession = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:nil];
    });
    return backgroundSession;
}
#endif

- (void)stop:(CDVInvokedUrlCommand*)command
{
    // XXX TODO
#if 0
    CDVPluginResult* pluginResult = nil;
    NSString* myarg = [command.arguments objectAtIndex:0];
    
    if (myarg != nil) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Arg was null"];
    }
    
    [downloadTask cancel];
    
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
#endif
}

#if 0
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    NSMutableDictionary* progressObj = [NSMutableDictionary dictionaryWithCapacity:1];
    [progressObj setObject:[NSNumber numberWithInteger:totalBytesWritten] forKey:@"bytesReceived"];
    [progressObj setObject:[NSNumber numberWithInteger:totalBytesExpectedToWrite] forKey:@"totalBytesToReceive"];
    NSMutableDictionary* resObj = [NSMutableDictionary dictionaryWithCapacity:1];
    [resObj setObject:progressObj forKey:@"progress"];
    CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:resObj];
    result.keepCallback = [NSNumber numberWithInteger: TRUE];
    [self.commandDelegate sendPluginResult:result callbackId:self.callbackId];
}

-(void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if (ignoreNextError) {
        ignoreNextError = NO;
        return;
    }
    
    if (error != nil) {
        if ((error.code == -999)) {
            NSData* resumeData = [[error userInfo] objectForKey:NSURLSessionDownloadTaskResumeData];
            // resumeData is available only if operation was terminated by the system (no connection or other reason)
            // this happens when application is closed when there is pending download, so we try to resume it
            if (resumeData != nil) {
                ignoreNextError = YES;
                [downloadTask cancel];
                downloadTask = [self.session downloadTaskWithResumeData:resumeData];
                [downloadTask resume];
                return;
            }
        }
        CDVPluginResult* errorResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[error localizedDescription]];
        [self.commandDelegate sendPluginResult:errorResult callbackId:self.callbackId];
    } else {
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:self.callbackId];
    }
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSURL *targetURL = [NSURL URLWithString:_targetFile];
    
    [fileManager removeItemAtPath:targetURL.path error: nil];
    [fileManager createFileAtPath:targetURL.path contents:[fileManager contentsAtPath:[location path]] attributes:nil];
}
#endif

@end
