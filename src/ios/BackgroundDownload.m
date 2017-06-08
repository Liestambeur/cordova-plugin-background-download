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

@implementation BackgroundDownload

- (NSDictionary *)cookieMap:(NSString*)cookie{
    NSMutableDictionary *cookieMap = [NSMutableDictionary dictionary];

    NSArray *cookieKeyValueStrings = [cookie componentsSeparatedByString:@";"];
    for (NSString *cookieKeyValueString in cookieKeyValueStrings) {
        NSRange separatorRange = [cookieKeyValueString rangeOfString:@"="];

        if (separatorRange.location != NSNotFound &&
            separatorRange.location > 0 &&
            separatorRange.location < ([cookieKeyValueString length] - 1)) {

            NSRange keyRange = NSMakeRange(0, separatorRange.location);
            NSString *key = [cookieKeyValueString substringWithRange:keyRange];
            NSString *value = [cookieKeyValueString substringFromIndex:separatorRange.location + separatorRange.length];

            key = [key stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            value = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            [cookieMap setObject:value forKey:key];
        }
    }
    return cookieMap;
}

- (NSDictionary *)cookieProperties:(NSString*)cookie{
    NSDictionary *cookieMap = [self cookieMap:cookie];

    NSMutableDictionary *cookieProperties = [NSMutableDictionary dictionary];
    for (NSString *key in [cookieMap allKeys]) {

        NSString *value = [cookieMap objectForKey:key];
        NSString *uppercaseKey = [key uppercaseString];

        if ([uppercaseKey isEqualToString:@"DOMAIN"]) {
            if (![value hasPrefix:@"."] && ![value hasPrefix:@"www"]) {
                value = [NSString stringWithFormat:@".%@",value];
            }
            [cookieProperties setObject:value forKey:NSHTTPCookieDomain];
        }else if ([uppercaseKey isEqualToString:@"VERSION"]) {
            [cookieProperties setObject:value forKey:NSHTTPCookieVersion];
        }else if ([uppercaseKey isEqualToString:@"MAX-AGE"]||[uppercaseKey isEqualToString:@"MAXAGE"]) {
            [cookieProperties setObject:value forKey:NSHTTPCookieMaximumAge];
        }else if ([uppercaseKey isEqualToString:@"PATH"]) {
            [cookieProperties setObject:value forKey:NSHTTPCookiePath];
        }else if([uppercaseKey isEqualToString:@"ORIGINURL"]){
            [cookieProperties setObject:value forKey:NSHTTPCookieOriginURL];
        }else if([uppercaseKey isEqualToString:@"PORT"]){
            [cookieProperties setObject:value forKey:NSHTTPCookiePort];
        }else if([uppercaseKey isEqualToString:@"SECURE"]||[uppercaseKey isEqualToString:@"ISSECURE"]){
            [cookieProperties setObject:value forKey:NSHTTPCookieSecure];
        }else if([uppercaseKey isEqualToString:@"COMMENT"]){
            [cookieProperties setObject:value forKey:NSHTTPCookieComment];
        }else if([uppercaseKey isEqualToString:@"COMMENTURL"]){
            [cookieProperties setObject:value forKey:NSHTTPCookieCommentURL];
        }else if([uppercaseKey isEqualToString:@"EXPIRES"]){
            NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
            [dateFormatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US"]];
            dateFormatter.dateFormat = @"EEE, dd-MMM-yyyy HH:mm:ss zzz";
            [cookieProperties setObject:[dateFormatter dateFromString:value] forKey:NSHTTPCookieExpires];
        }else if([uppercaseKey isEqualToString:@"DISCART"]){
            [cookieProperties setObject:value forKey:NSHTTPCookieDiscard];
        }else if([uppercaseKey isEqualToString:@"NAME"]){
            [cookieProperties setObject:value forKey:NSHTTPCookieName];
        }else if([uppercaseKey isEqualToString:@"VALUE"]){
            [cookieProperties setObject:value forKey:NSHTTPCookieValue];
        }else{
            [cookieProperties setObject:key forKey:NSHTTPCookieName];
            [cookieProperties setObject:value forKey:NSHTTPCookieValue];
        }
    }
        if (![cookieProperties objectForKey:NSHTTPCookiePath]) {
        [cookieProperties setObject:@"/" forKey:NSHTTPCookiePath];
    }
    return cookieProperties;
}

- (NSHTTPCookie *)createCookie:(NSString*)cookie {
  NSDictionary *cookieProperties = [self cookieProperties:cookie];
  NSHTTPCookie *resultCookie = [NSHTTPCookie cookieWithProperties:cookieProperties];
  return resultCookie;
}

- (void)setCookies: (NSArray*)cookies
{
  NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
  NSHTTPCookieStorage *cookieStorage = [configuration HTTPCookieStorage];

  int i;
  for (i = 0; i < [cookies count]; i++) {
   NSString *cookieString = [cookies objectAtIndex:i];
   NSHTTPCookie *cookie = [self createCookie:cookieString];
   [cookieStorage setCookie:cookie];
  }

}

- (void)startAsync:(CDVInvokedUrlCommand*)command
{
    NSString * downloadUri = [command.arguments objectAtIndex:0];
    NSString * targetFile = [command.arguments objectAtIndex:1];
    NSArray * cookies = [command.arguments objectAtIndex:2];
    [self setCookies:cookies];

    NSString * cbid = command.callbackId;

    [[TWRDownloadManager sharedManager] downloadFileForURL: downloadUri toAbsolutePathURL: targetFile progressBlock:^(CGFloat p) {
        /* TODO (IGNORED FOR NOW) */
    } remainingTime: nil completionBlock: ^(NSInteger completed){
        if (completed > 0) {
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[@(completed) stringValue]];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:cbid];
        } else {
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:cbid];
        }
    } enableBackgroundMode:false];

#if 0
    self.downloadUri = [command.arguments objectAtIndex:0];
    self.targetFile = [command.arguments objectAtIndex:1];

    self.callbackId = command.callbackId;

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
#endif

    CDVPluginResult * pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"NOT IMPLEMENTED"];

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
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
