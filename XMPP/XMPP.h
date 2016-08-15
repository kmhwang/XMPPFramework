//
//  XMPP.h
//  XMPP
//
//  Created by Ken M. Hwang on 8/12/16.
//  Copyright © 2016 Ken M. Hwang. All rights reserved.
//

#import <Foundation/Foundation.h>

//! Project version number for XMPP.
FOUNDATION_EXPORT double XMPPVersionNumber;

//! Project version string for XMPP.
FOUNDATION_EXPORT const unsigned char XMPPVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <XMPP/PublicHeader.h>

//
// Core classes
//

#import <XMPP/XMPPJID.h>
#import <XMPP/XMPPStream.h>
#import <XMPP/XMPPElement.h>
#import <XMPP/XMPPIQ.h>
#import <XMPP/XMPPMessage.h>
#import <XMPP/XMPPPresence.h>
#import <XMPP/XMPPModule.h>

//
// Authentication
//

#import <XMPP/XMPPSASLAuthentication.h>
#import <XMPP/XMPPCustomBinding.h>
#import <XMPP/XMPPDigestMD5Authentication.h>
#import <XMPP/XMPPSCRAMSHA1Authentication.h>
#import <XMPP/XMPPPlainAuthentication.h>
#import <XMPP/XMPPXFacebookPlatformAuthentication.h>
#import <XMPP/XMPPXOAuth2Google.h>
#import <XMPP/XMPPAnonymousAuthentication.h>
#import <XMPP/XMPPDeprecatedPlainAuthentication.h>
#import <XMPP/XMPPDeprecatedDigestAuthentication.h>

//
// Categories
//

#import <XMPP/NSXMLElement+XMPP.h>

//
// Extensions
//

#import <XMPP/XMPPBandwidthMonitor.h>
#import <XMPP/XMPPGoogleSharedStatus.h>
#import <XMPP/XMPPReconnect.h>
#import <XMPP/XMPPRoster.h>
#import <XMPP/XMPPSystemInputActivityMonitor.h>
#import <XMPP/XMPPJabberRPCModule.h>
#import <XMPP/XMPPLastActivity.h>
#import <XMPP/XMPPPrivacy.h>
#import <XMPP/XMPPMUC.h>
#import <XMPP/XMPPRoom.h>
#import <XMPP/XMPPvCardTempModule.h>
#import <XMPP/XMPPPubSub.h>
#import <XMPP/XMPPRegistration.h>
#import <XMPP/XMPPTransports.h>
#import <XMPP/XMPPCapabilities.h>
#import <XMPP/XMPPMessageArchiving.h>
#import <XMPP/XMPPvCardAvatarModule.h>
#import <XMPP/XMPPMessageDeliveryReceipts.h>
#import <XMPP/XMPPBlocking.h>
#import <XMPP/XMPPStreamManagement.h>
#import <XMPP/XMPPAutoPing.h>
#import <XMPP/XMPPPing.h>
#import <XMPP/XMPPAutoTime.h>
#import <XMPP/XMPPTime.h>
#import <XMPP/XMPPAttentionModule.h>
#import <XMPP/XMPPMessageCarbons.h>
