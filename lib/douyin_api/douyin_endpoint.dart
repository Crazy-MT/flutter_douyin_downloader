enum EndpointGroup { user, video }

enum EndpointMethod { get, post }

class DouyinEndpoint {
  const DouyinEndpoint({
    required this.group,
    required this.title,
    required this.remoteUri,
    required this.params,
    this.method = EndpointMethod.get,
    this.host = DouyinHost.www,
    this.bodyParams = const <String>[],
    this.defaults = const <String, String>{},
    this.needsWebSign = false,
  });

  final EndpointGroup group;
  final String title;
  final String remoteUri;
  final List<String> params;
  final EndpointMethod method;
  final DouyinHost host;
  final List<String> bodyParams;
  final Map<String, String> defaults;
  final bool needsWebSign;
}

enum DouyinHost { www, live, web2 }

const userEndpoints = <DouyinEndpoint>[
  DouyinEndpoint(
      group: EndpointGroup.user,
      title: '当前用户信息',
      remoteUri: '/aweme/v1/web/user/profile/self/',
      params: []),
  DouyinEndpoint(
      group: EndpointGroup.user,
      title: '其他用户信息',
      remoteUri: '/aweme/v1/web/user/profile/other/',
      params: [
        'sec_user_id'
      ],
      defaults: {
        'source': 'channel_pc_web',
        'publish_video_strategy_type': '2',
        'personal_center_strategy': '1'
      }),
  DouyinEndpoint(
      group: EndpointGroup.user,
      title: '用户作品列表',
      remoteUri: '/aweme/v1/web/aweme/post/',
      params: [
        'sec_user_id',
        'count',
        'max_cursor',
        'locate_item_id',
        'need_time_list',
        'locate_query',
        'forward_anchor_cursor',
        'forward_end_cursor',
        'locate_item_cursor'
      ],
      defaults: {
        'show_live_replay_strategy': '1',
        'time_list_query': '0',
        'publish_video_strategy_type': '2'
      }),
  DouyinEndpoint(
      group: EndpointGroup.user,
      title: '用户私密作品列表',
      remoteUri: '/aweme/v1/web/private/aweme/',
      params: ['min_cursor', 'max_cursor', 'count'],
      defaults: {'pc_client_type': '1'}),
  DouyinEndpoint(
      group: EndpointGroup.user,
      title: '定位作品列表',
      remoteUri: '/aweme/v1/web/locate/post/',
      host: DouyinHost.web2,
      params: [
        'sec_user_id',
        'max_cursor',
        'locate_item_id',
        'locate_item_cursor',
        'locate_query',
        'count'
      ],
      defaults: {
        'count': '10',
        'max_cursor': '0',
        'locate_query': 'true',
        'publish_video_strategy_type': '2',
        'pc_libra_divert': 'Windows',
        'support_h265': '0',
        'support_dash': '0'
      }),
  DouyinEndpoint(
      group: EndpointGroup.user,
      title: '用户喜欢列表',
      remoteUri: '/aweme/v1/web/aweme/favorite/',
      host: DouyinHost.web2,
      params: ['sec_user_id', 'count', 'min_cursor', 'max_cursor'],
      defaults: {
        'count': '18',
        'min_cursor': '0',
        'max_cursor': '0',
        'whale_cut_token': '',
        'cut_version': '1',
        'publish_video_strategy_type': '2'
      },
      needsWebSign: true),
  DouyinEndpoint(
      group: EndpointGroup.user,
      title: '收藏视频列表',
      remoteUri: '/aweme/v1/web/aweme/listcollection/',
      method: EndpointMethod.post,
      params: ['count', 'cursor'],
      bodyParams: ['count', 'cursor']),
  DouyinEndpoint(
      group: EndpointGroup.user,
      title: '音乐详情',
      remoteUri: '/aweme/v1/web/music/detail/',
      params: ['music_id', 'scene']),
  DouyinEndpoint(
      group: EndpointGroup.user,
      title: '收藏音乐列表',
      remoteUri: '/aweme/v1/web/music/listcollection/',
      params: ['count', 'cursor']),
  DouyinEndpoint(
      group: EndpointGroup.user,
      title: '收藏夹列表',
      remoteUri: '/aweme/v1/web/collects/list/',
      params: ['count', 'cursor']),
  DouyinEndpoint(
      group: EndpointGroup.user,
      title: '收藏夹视频信息',
      remoteUri: '/aweme/v1/web/collects/video/list/',
      params: ['collects_id', 'count', 'cursor']),
  DouyinEndpoint(
      group: EndpointGroup.user,
      title: '收藏的合集',
      remoteUri: '/aweme/v1/web/mix/listcollection/',
      params: ['count', 'cursor']),
  DouyinEndpoint(
      group: EndpointGroup.user,
      title: '收藏的短剧',
      remoteUri: '/aweme/v1/web/series/collections',
      params: ['count', 'cursor']),
  DouyinEndpoint(
      group: EndpointGroup.user,
      title: '用户创建的合集',
      remoteUri: '/aweme/v1/web/mix/list/',
      params: ['sec_user_id', 'count', 'cursor', 'list_scene'],
      defaults: {'req_from': 'channel_pc_web'}),
  DouyinEndpoint(
      group: EndpointGroup.user,
      title: '合集详情',
      remoteUri: '/aweme/v1/web/mix/detail/',
      params: ['mix_id']),
  DouyinEndpoint(
      group: EndpointGroup.user,
      title: '合集作品列表',
      remoteUri: '/aweme/v1/web/mix/aweme/',
      params: ['mix_id', 'count', 'cursor']),
  DouyinEndpoint(
      group: EndpointGroup.user,
      title: '访客列表',
      remoteUri: '/aweme/v1/web/view/user/visited/list/',
      method: EndpointMethod.post,
      params: ['count', 'cursor'],
      bodyParams: ['count', 'cursor']),
  DouyinEndpoint(
      group: EndpointGroup.user,
      title: '观看历史列表',
      remoteUri: '/aweme/v1/web/history/read/',
      params: ['count', 'max_cursor', 'directory', 'category', 'status']),
  DouyinEndpoint(
      group: EndpointGroup.user,
      title: '影视综观看历史',
      remoteUri: '/aweme/v1/web/lvideo/query/history/',
      params: ['count', 'cursor']),
  DouyinEndpoint(
      group: EndpointGroup.user,
      title: '直播观看历史',
      remoteUri: '/webcast/feed/',
      host: DouyinHost.live,
      params: [
        'max_time'
      ],
      defaults: {
        'live_id': '1',
        'source_key': 'drawer_hot_live_history',
        'need_map': '1'
      }),
  DouyinEndpoint(
      group: EndpointGroup.user,
      title: '用户关系列表',
      remoteUri: '/aweme/v1/web/im/spotlight/relation/',
      params: [
        'count',
        'min_time',
        'max_time'
      ],
      defaults: {
        'need_remove_share_panel': 'true',
        'need_sorted_info': 'true',
        'with_fstatus': '1'
      }),
  DouyinEndpoint(
      group: EndpointGroup.user,
      title: '用户关注列表',
      remoteUri: '/aweme/v1/web/user/following/list/',
      params: [
        'user_id',
        'sec_user_id',
        'count',
        'source_type',
        'offset',
        'min_time',
        'max_time',
        'is_top'
      ],
      defaults: {
        'gps_access': '0',
        'address_book_access': '0'
      }),
  DouyinEndpoint(
      group: EndpointGroup.user,
      title: '粉丝列表',
      remoteUri: '/aweme/v1/web/user/follower/list/',
      params: [
        'user_id',
        'sec_user_id',
        'count',
        'source_type',
        'offset',
        'min_time',
        'max_time'
      ],
      defaults: {
        'gps_access': '0',
        'address_book_access': '0',
        'is_top': '1'
      }),
  DouyinEndpoint(
      group: EndpointGroup.user,
      title: '用户主页搜索',
      remoteUri: '/aweme/v1/web/home/search/item/',
      params: [
        'search_channel',
        'search_source',
        'search_scene',
        'sort_type',
        'keyword',
        'from_user',
        'count',
        'offset',
        'publish_time',
        'is_filter_search',
        'query_correct_type',
        'enable_history'
      ],
      defaults: {
        'search_id': ''
      }),
  DouyinEndpoint(
      group: EndpointGroup.user,
      title: '短剧列表',
      remoteUri: '/aweme/v1/web/series/list/',
      params: ['sec_user_id', 'cursor', 'count'],
      defaults: {'req_from': 'channel_pc_web'}),
  DouyinEndpoint(
      group: EndpointGroup.user,
      title: '关注人的视频',
      remoteUri: '/aweme/v1/web/user/follower/list/',
      params: [
        'cursor',
        'level',
        'count',
        'pull_type',
        'refresh_type',
        'aweme_ids',
        'room_ids'
      ],
      needsWebSign: true),
  DouyinEndpoint(
      group: EndpointGroup.user,
      title: '稍后再看',
      remoteUri: '/aweme/v1/web/watchlater/list/',
      params: ['offset', 'list_type', 'operate_type']),
  DouyinEndpoint(
      group: EndpointGroup.user,
      title: 'AT 列表',
      remoteUri: '/aweme/v1/web/familiar/atlist/',
      params: ['count', 'cursor', 'scene', 'group_id'],
      defaults: {'need_page': 'true'}),
  DouyinEndpoint(
      group: EndpointGroup.user,
      title: '获取二维码',
      remoteUri: '/aweme/v1/web/fancy/qrcode/info/',
      method: EndpointMethod.post,
      params: ['app_name', 'schema_type', 'object_id', 'qrcode_type'],
      bodyParams: ['app_name', 'schema_type', 'object_id', 'qrcode_type']),
];

const videoEndpoints = <DouyinEndpoint>[
  DouyinEndpoint(
      group: EndpointGroup.video,
      title: '视频详细信息',
      remoteUri: '/aweme/v1/web/aweme/detail/',
      params: ['aweme_id']),
  DouyinEndpoint(
      group: EndpointGroup.video,
      title: '相关视频',
      remoteUri: '/aweme/v1/web/aweme/related/',
      params: [
        'aweme_id',
        'count',
        'filterGids',
        'refresh_index'
      ],
      defaults: {
        'awemePcRecRawData': '{"is_client":false}',
        'sub_channel_id': '0',
        'Seo-Flag': '0'
      }),
  DouyinEndpoint(
      group: EndpointGroup.video,
      title: '视频评论',
      remoteUri: '/aweme/v1/web/comment/list/',
      params: ['aweme_id', 'cursor', 'count']),
  DouyinEndpoint(
      group: EndpointGroup.video,
      title: '评论回复',
      remoteUri: '/aweme/v1/web/comment/list/reply/',
      params: ['item_id', 'comment_id', 'cursor', 'count']),
  DouyinEndpoint(
      group: EndpointGroup.video,
      title: '首页瀑布流',
      remoteUri: '/aweme/v2/web/module/feed/',
      method: EndpointMethod.post,
      params: [
        'count',
        'refresh_index',
        'tag_id',
        'presented_ids',
        'filter_gids',
        'is_active_tab',
        'active_id'
      ],
      defaults: {
        'count': '20',
        'refresh_index': '1',
        'module_id': '3003101',
        'refer_id': '',
        'refer_type': '10',
        'pull_type': '2',
        'awemePcRecRawData':
            '{"is_xigua_user":0,"danmaku_switch_status":1,"is_client":false}',
        'Seo-Flag': '0',
        'use_lite_type': '0',
        'xigua_user': '0',
        'pc_libra_divert': 'Windows',
        'support_h265': '0',
        'support_dash': '0'
      },
      needsWebSign: true),
  DouyinEndpoint(
      group: EndpointGroup.video,
      title: '推荐页 Feed',
      remoteUri: '/aweme/v1/web/tab/feed/',
      params: ['count', 'refresh_index'],
      defaults: {
        'video_type_select': '1',
        'aweme_pc_rec_raw_data':
            '{"is_client":false,"ff_danmaku_status":1,"danmaku_switch_status":1,"is_auto_play":0,"is_full_screen":0,"is_full_webscreen":0,"is_mute":0,"is_speed":1,"is_visible":1,"related_recommend":1}'
      },
      needsWebSign: true),
  DouyinEndpoint(
      group: EndpointGroup.video,
      title: '用户点赞/取消',
      remoteUri: '/aweme/v1/web/commit/item/digg/',
      method: EndpointMethod.post,
      host: DouyinHost.web2,
      params: ['aweme_id', 'type', 'item_type'],
      bodyParams: ['aweme_id', 'type', 'item_type']),
];

const allEndpoints = <DouyinEndpoint>[...userEndpoints, ...videoEndpoints];
