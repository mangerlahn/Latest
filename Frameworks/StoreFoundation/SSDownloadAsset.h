//
//  SSDownloadAsset.h
//  Latest
//
//  Created by Max Langer on 31.01.26.
//  Copyright © 2026 Max Langer. All rights reserved.
//


@interface SSDownloadAsset: NSObject

@property(readonly) NSString *downloadPath;
@property(readonly) NSString *processedPath;

@property(readonly) NSString *downloadFileName;
@property(readonly) NSString *downloadFolderName;

@property NSString *customDownloadPath;
@property BOOL skipDownloadPhase;

@end
