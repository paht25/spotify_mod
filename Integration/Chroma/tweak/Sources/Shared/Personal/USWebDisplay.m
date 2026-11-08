// Independent, opt-in private-Wi-Fi display. No Chroma relay/account/service.
// Audio and Spotify credentials never leave the phone.
#import "USWebDisplay.h"
#import "Core/USLocalHTTP.h"
#import "Core/USRuntimeState.h"
#import "Shared/Player/PlayerState.h"
#import "Shared/Lyrics/Lyrics.h"
#import <Network/Network.h>
#import <Security/Security.h>
#import <MediaPlayer/MediaPlayer.h>
#include <ifaddrs.h>
#include <arpa/inet.h>
#include <net/if.h>
#include <math.h>
#include <string.h>
#include <stdlib.h>

static NSString *wifiAddress(void) {
    struct ifaddrs *interfaces=NULL;if(getifaddrs(&interfaces)!=0)return nil;NSString *result=nil;
    for(struct ifaddrs *i=interfaces;i;i=i->ifa_next){
        if(!i->ifa_addr||i->ifa_addr->sa_family!=AF_INET||strcmp(i->ifa_name,"en0")||!(i->ifa_flags&IFF_UP))continue;
        struct sockaddr_in *address=(struct sockaddr_in *)i->ifa_addr;
        uint32_t ip=ntohl(address->sin_addr.s_addr);
        BOOL private=(ip>>24)==10||(ip>>16)==0xc0a8||(ip>>20)==0xac1;
        char text[INET_ADDRSTRLEN];if(private&&inet_ntop(AF_INET,&address->sin_addr,text,sizeof(text)))result=@(text);
    }freeifaddrs(interfaces);return result;
}
static void respond(nw_connection_t connection,NSInteger code,NSString *type,NSData *body) {
    NSString *reason=code==200?@"OK":(code==403?@"Forbidden":@"Rejected");
    NSString *header=[NSString stringWithFormat:@"HTTP/1.1 %ld %@\r\nContent-Type: %@\r\nContent-Length: %lu\r\nConnection: close\r\nCache-Control: no-store\r\nReferrer-Policy: no-referrer\r\nX-Content-Type-Options: nosniff\r\nContent-Security-Policy: default-src 'self'; img-src data:; script-src 'unsafe-inline'; style-src 'unsafe-inline'; frame-ancestors 'none'\r\n\r\n",(long)code,reason,type,(unsigned long)body.length];
    NSMutableData *all=[[header dataUsingEncoding:NSUTF8StringEncoding] mutableCopy];[all appendData:body];
    void *storage=malloc(all.length);if(!storage){nw_connection_cancel(connection);return;}memcpy(storage,all.bytes,all.length);
    dispatch_data_t content=dispatch_data_create(storage,all.length,dispatch_get_global_queue(QOS_CLASS_DEFAULT,0),DISPATCH_DATA_DESTRUCTOR_FREE);
    nw_connection_send(connection,content,NW_CONNECTION_DEFAULT_MESSAGE_CONTEXT,true,^(nw_error_t error){(void)error;nw_connection_cancel(connection);});
}
static NSData *json(id value){return [NSJSONSerialization dataWithJSONObject:value options:0 error:nil]?:[NSData data];}
static NSDictionary *snapshot(void) {
    // Main-thread snapshot of the existing shared player/lyrics owners.
    SPTPlayerState *state=SGPlayerState();NSString *track=SGKaraokePlayingTrack();
    NSMutableDictionary *value=[@{@"title":state.track.trackTitle?:@"",@"artist":state.track.artistName?:@"",
        @"position":@(MAX(0,SGKaraokePositionMs())/1000.0),@"duration":@(isfinite(state.duration)?MAX(0,state.duration):0),
        @"playing":@(state&&state.isPlaying&&!state.isPaused),
        @"controls":@(state&&SGKaraokePlayer()&&[NSUserDefaults.standardUserDefaults boolForKey:@"unifiedspotify.personal.webControl"])} mutableCopy];
    NSMutableArray *lines=[NSMutableArray array];
    NSArray *kept=track.length?SGKaraokeLinesForTrack(track):@[];
    for(SGKaraokeLine *line in kept){
        if(lines.count>=200)break;NSMutableArray *words=[NSMutableArray array];
        for(SGKaraokeWord *word in line.words){
            if(words.count>=100)break;[words addObject:@{@"text":word.text?:@"",@"start":@(word.start),@"end":@(word.end),@"joined":@(word.joined)}];
        }
        [lines addObject:@{@"start":@(line.start),@"end":@(line.end),@"words":words,@"translation":line.translation?:@"",
            @"wordTimed":@(line.timing==SGKaraokeTimingWords||[NSUserDefaults.standardUserDefaults boolForKey:SGKeyLyricsSimulateWords])}];
    }
    value[@"lines"]=lines;
    // Artwork is copied at a bounded size; no authenticated image URL is shared.
    MPMediaItemArtwork *art=MPNowPlayingInfoCenter.defaultCenter.nowPlayingInfo[MPMediaItemPropertyArtwork];
    static __weak MPMediaItemArtwork *lastArt;static NSString *lastTrack,*encoded;
    if([art isKindOfClass:MPMediaItemArtwork.class]){
        if(lastArt!=art||![lastTrack isEqual:track]){
            UIImage *image=[art imageWithSize:CGSizeMake(256,256)];NSData *data=image?UIImageJPEGRepresentation(image,.65):nil;
            encoded=data.length<100000?[data base64EncodedStringWithOptions:0]:nil;lastArt=art;lastTrack=[track copy];
        }
        if(encoded)value[@"cover"]=[@"data:image/jpeg;base64," stringByAppendingString:encoded];
    }
    return value;
}
static BOOL command(NSDictionary *body) {
    id<SPTPlayer> player=SGKaraokePlayer();if(!player)return NO;NSString *action=body[@"action"];
    if([action isEqual:@"toggle"]){
        SEL selector=SGPlayerState().isPaused?@selector(resume:):@selector(pause:);
        if(![player respondsToSelector:selector])return NO;
        if(SGPlayerState().isPaused)[player resume:nil];else [player pause:nil];return YES;
    }
    if([action isEqual:@"next"]&&[player respondsToSelector:@selector(skipToNextTrackWithOptions:)]){[player skipToNextTrackWithOptions:nil];return YES;}
    if([action isEqual:@"previous"]&&[player respondsToSelector:@selector(skipToPreviousTrackWithOptions:)]){[player skipToPreviousTrackWithOptions:nil];return YES;}
    if([action isEqual:@"seek"]){
        id seconds=body[@"seconds"];double duration=SGPlayerState().duration;
        if(![seconds isKindOfClass:NSNumber.class]||!isfinite([seconds doubleValue])||!isfinite(duration)||duration<=0)return NO;
        SGKaraokeSeek((NSInteger)(MAX(0,MIN(duration,[seconds doubleValue]))*1000));return YES;
    }
    return NO;
}
@interface USWebDisplay : NSObject
@property(nonatomic,strong) nw_listener_t listener;
@property(nonatomic,copy) NSString *link,*status;
@property(nonatomic) NSUInteger generation;
@property(nonatomic) CFAbsoluteTime lastCommand;
@end
@implementation USWebDisplay
- (void)receive:(nw_connection_t)connection data:(NSMutableData *)bytes token:(NSString *)token generation:(NSUInteger)generation {
    nw_connection_receive(connection,1,4096,^(dispatch_data_t content,nw_content_context_t context,bool complete,nw_error_t issue){
        (void)context;
        if(content)dispatch_data_apply(content,^bool(dispatch_data_t region,size_t offset,const void *buffer,size_t size){(void)region;(void)offset;[bytes appendBytes:buffer length:size];return true;});
        BOOL more=NO;NSError *error=nil;NSDictionary *request=USParseLocalRequest(bytes,&more,&error);
        if(!request){
            if(more&&!issue&&!complete){[self receive:connection data:bytes token:token generation:generation];return;}
            respond(connection,400,@"application/json",json(@{@"error":@"Invalid request"}));return;
        }
        if([request[@"path"]isEqual:@"/"]){
            NSString *path=[NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:@"UnifiedSpotifyPersonal/WebDisplay.html"];
            NSData *page=[NSData dataWithContentsOfFile:path];
            respond(connection,page?200:503,@"text/html; charset=utf-8",page?:[@"Web resource missing; use assembled IPA" dataUsingEncoding:NSUTF8StringEncoding]);return;
        }
        if(!USLocalCapabilityMatches(request[@"headers"][@"authorization"],token)){
            respond(connection,403,@"application/json",json(@{@"error":@"Open the private link copied from the phone"}));return;
        }
        dispatch_async(dispatch_get_main_queue(),^{
            if(generation!=self.generation||!self.listener){respond(connection,403,@"application/json",json(@{@"error":@"Sharing stopped"}));return;}
            if([request[@"path"]isEqual:@"/state"]){respond(connection,200,@"application/json",json(snapshot()));return;}
            BOOL allowed=[NSUserDefaults.standardUserDefaults boolForKey:@"unifiedspotify.personal.webControl"];
            if(!allowed||CFAbsoluteTimeGetCurrent()-self.lastCommand<.3){respond(connection,403,@"application/json",json(@{@"error":@"Control is disabled or rate-limited"}));return;}
            id body=[NSJSONSerialization JSONObjectWithData:request[@"body"] options:0 error:nil];
            self.lastCommand=CFAbsoluteTimeGetCurrent();BOOL ok=[body isKindOfClass:NSDictionary.class]&&command(body);
            respond(connection,ok?200:400,@"application/json",json(@{@"ok":@(ok)}));
        });
    });
}
@end
static USWebDisplay *server(void){static USWebDisplay *s;static dispatch_once_t once;dispatch_once(&once,^{s=[USWebDisplay new];s.status=@"Stopped";});return s;}
void USStopWebDisplay(void) {
    USWebDisplay *s=server();s.generation++;if(s.listener)nw_listener_cancel(s.listener);s.listener=nil;s.link=nil;s.status=@"Stopped";
}
void USStartWebDisplay(void) {
    USStopWebDisplay();USWebDisplay *s=server();NSString *address=wifiAddress();
    if(!address){s.status=@"Connect to a private Wi-Fi network first";return;}
    uint8_t random[32];if(SecRandomCopyBytes(kSecRandomDefault,sizeof(random),random)!=errSecSuccess){s.status=@"Could not create private link";return;}
    NSMutableString *token=[NSMutableString string];for(unsigned i=0;i<sizeof(random);i++)[token appendFormat:@"%02x",random[i]];
    nw_parameters_t parameters=nw_parameters_create_secure_tcp(NW_PARAMETERS_DISABLE_PROTOCOL,NW_PARAMETERS_DEFAULT_CONFIGURATION);
    nw_parameters_set_local_endpoint(parameters,nw_endpoint_create_host(address.UTF8String,"0"));
    nw_parameters_set_required_interface_type(parameters,nw_interface_type_wifi);
    nw_listener_t listener=nw_listener_create_with_port("0",parameters);if(!listener){s.status=@"Could not create local listener";return;}
    s.listener=listener;s.status=@"Starting";NSUInteger generation=s.generation;
    dispatch_queue_t queue=dispatch_queue_create("personal.web-display",DISPATCH_QUEUE_SERIAL);
    NSMutableDictionary<NSValue *,id> *connections=[NSMutableDictionary dictionary];
    nw_listener_set_queue(listener,queue);
    nw_listener_set_state_changed_handler(listener,^(nw_listener_state_t state,nw_error_t error){
        (void)error;
        dispatch_async(dispatch_get_main_queue(),^{
            if(generation!=s.generation||!s.listener)return;
            nw_listener_t active=s.listener;uint16_t port=nw_listener_get_port(active);
            if(state==nw_listener_state_ready){s.status=@"Ready on private Wi-Fi";s.link=[NSString stringWithFormat:@"http://%@:%u/#%@",address,port,token];}
            else if(state==nw_listener_state_failed){s.status=@"Local network listener failed";nw_listener_cancel(active);s.listener=nil;s.link=nil;}
        });
    });
    nw_listener_set_new_connection_handler(listener,^(nw_connection_t connection){
        if(connections.count>=16){nw_connection_cancel(connection);return;}
        NSValue *key=[NSValue valueWithPointer:(__bridge const void *)connection];
        connections[key]=connection;nw_connection_set_queue(connection,queue);
        nw_connection_set_state_changed_handler(connection,^(nw_connection_state_t state,nw_error_t error){
            (void)error;if(state==nw_connection_state_cancelled||state==nw_connection_state_failed)[connections removeObjectForKey:key];
        });
        nw_connection_start(connection);[s receive:connection data:[NSMutableData data] token:token generation:generation];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,5*NSEC_PER_SEC),queue,^{nw_connection_cancel(connection);});
    });
    nw_listener_start(listener);
}
NSString *USWebDisplayStatus(void){return server().status;}
NSString *USWebDisplayLink(void){return server().link;}
