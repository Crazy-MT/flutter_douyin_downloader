// ignore_for_file: prefer_generic_function_type_aliases

import 'dart:io';

import 'package:code_zero/common/common.dart';
import 'package:code_zero/utils/platform_utils.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import '../utils/log_utils.dart';
import '../utils/utils.dart';
import 'base_model.dart';
import 'convert_interface.dart';

typedef ErrorCallback(int errorCode, String errorMsg, String expMsg);
typedef HandleBaseModel(BaseModel baseModel);
typedef OnSuccess<T>(ResultData<T> resultData);
typedef OnStringSuccess(String resultData);

// ignore: constant_identifier_names
enum RequestType { GET, POST, PUT, DELETE }

class LRequest {
  static Dio dio = Dio();

  LRequest._();

  static final LRequest _lRequest = LRequest._();

  static LRequest get instance => _lRequest;

  void init() {
    // dio..interceptors.add(InterceptorsWrapper(onError: (DioError dioError) => errorInterceptor(dioError)));
    lLog('LRequest.init ${Platform.operatingSystem} ');
    // dio.interceptors.add(_dioCacheManager.interceptor);
    dio.options.connectTimeout = Duration(seconds: 10);
    dio.options.receiveTimeout = Duration(seconds: 5 * 60);
    dio.options.sendTimeout = Duration(seconds: 10);

    if (!PlatformUtils.isWeb) {
      (dio.httpClientAdapter as DefaultHttpClientAdapter).onHttpClientCreate =
          (client) {
        client.badCertificateCallback =
            (X509Certificate cert, String host, int port) {
          return true;
        };
        /*client.findProxy = (uri) {
        return "PROXY 172.16.24.136:8888";
      };*/
        return client;
      };
    }
    // setProxy(SpUtil.getString(Constant.SP_KEY_SAVE_PROXY));
  }

  Future<Response> requestGet({
    Map<String, dynamic>? header,
    required String url,
  }) async {
    // url = common.host + url;

    dio.options.headers = header;

    /*header?.forEach((key, value) {
      if (kDebugMode) {
        print("requestGet : Key: $key, Value: $value");
      }
    });*/
    Response response = (await dio.get(url));
    return response;
  }

  // 此方法必须 try{}catch(){} 或者 传入 errorBack
  Future<ResultData<T>?> request<T extends ConvertInterface>(
      {required String path,
      String? url,
      T? t,
      requestType = RequestType.GET,
      Map<String, dynamic>? data,
      Map<String, dynamic>? queryParameters,
      bool needHeader = true,
      bool noCache = true,
      bool skipError = false,
      bool stringResult = false,
      HandleBaseModel? handleBaseModel,
      ErrorCallback? errorBack,
      OnSuccess<T>? onSuccess,
      OnStringSuccess? onStringSuccess,
      bool isShowErrorToast = true,
      FormData? formData,
      bool isShowLoading = true,
      bool isShowLog = false,
      Options? options,
      bool isFloat = false}) async {
    if (url != null) {
      path = url;
    } else {
      path = common.host + path;
    }

    Response response;

    // 如果没有传 options，就新建一个默认的
    options ??= Options();

    // 加通用 header
    if (needHeader) {
      options.headers ??= {};
    }

    try {
      if (isShowLog) lLog("request $requestType start =======>net: $path");
      if (isShowLoading) {
        EasyLoading.show();
      }
      if (requestType == RequestType.GET) {
        response = await dio.get(path,
            queryParameters: queryParameters, options: options);
      } else if (requestType == RequestType.POST) {
        response =
            await dio.post(path, data: formData ?? data, options: options);
      } else if (requestType == RequestType.DELETE) {
        response = await dio.delete(path,
            queryParameters: queryParameters, options: options);
      } else {
        response =
            await dio.put(path, data: formData ?? data, options: options);
      }
      if (isShowLoading) {
        EasyLoading.dismiss();
      }
      if (isShowLog)
        lLog("request $requestType over =======>net: $path $response ");
      //同一错误处理，如果需要可以后面放开
      // if (!skipError) await handleError(response, context: context, url: url);
      BaseModel<T> baseModel = BaseModel.fromJson(response.data, t);
      handleBaseModel?.call(baseModel);
      if (baseModel.code.runtimeType.toString() == "String") {
        onStringSuccess?.call(response.toString());
        if (isShowLoading) {
          EasyLoading.dismiss();
        }
        return null;
      }

      /// 权限认证错误，跳转到登录页
      if (baseModel.code == 20012) {
        if (isShowLoading) {
          EasyLoading.dismiss();
        }
        return null;
      }

      if (baseModel.code != 1) {
        errorBack?.call(baseModel.code ?? -1, baseModel.message ?? "UnknownMsg",
            "ErrorCode:${baseModel.code}");
        if (isShowLoading) {
          EasyLoading.dismiss();
        }
        return null;
      }
      ResultData<T> resultData = ResultData();
      if (baseModel.data is List) {
        List<T> valueList = baseModel.data;
        resultData.valueList = valueList;
        resultData.value = valueList.isNotEmpty ? valueList.first : null;
        resultData.message = baseModel.message;
      } else if (baseModel.data is String) {
        resultData.message = baseModel.data;
      } else if (baseModel.data is int) {
        resultData.message = baseModel.message;
        resultData.intData = baseModel.data;
      } else if (baseModel.data is double) {
        resultData.message = baseModel.message;
        resultData.doubleData = baseModel.data;
      } else {
        resultData.value = baseModel.data;
        resultData.valueList = [resultData.value];
        resultData.message = baseModel.message;
      }
      onSuccess?.call(resultData);
      if (isShowLoading) {
        EasyLoading.dismiss();
      }
      return resultData;
    } on DioError catch (e) {
      if (isShowLoading) {
        EasyLoading.dismiss();
      }
      // print(e);
      // debugLog((e.response?.statusCode ?? -1).toString() + e.toString());
      // errorLog(e.toString());
      if (isShowLog) lLog('LRequest.request ${e} ');

      if (errorBack != null) {
        errorBack(e.response?.statusCode ?? -1, e.toString(), "网络错误");
      } else {
        handleError(
            e.response?.statusCode ?? -1, e.message ?? '', isShowErrorToast);
      }
      return null;
    } on Exception catch (e) {
      if (isShowLoading) {
        EasyLoading.dismiss();
      }
      errorLog(e.toString());
      if (errorBack != null) {
        errorBack(-1, "数据处理异常", e.toString());
      } else {
        handleError(-1, e.toString(), isShowErrorToast);
      }
      return null;
    }
  }

  handleError(int code, String message, bool isShowErrorToast) {
    if (code == -1 && isShowErrorToast) {
      Utils.showToastMsg("请求失败了，code:$code");
    }
  }

  userOutLoginError() {

  }
}
