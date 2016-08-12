#import <Foundation/Foundation.h>
#import "XMPPCore.h"


@protocol XMPPResource <NSObject>
@required

- (XMPPJID *)jid;
- (XMPPPresence *)presence;

- (NSDate *)presenceDate;

- (NSComparisonResult)compare:(id <XMPPResource>)another;

@end
