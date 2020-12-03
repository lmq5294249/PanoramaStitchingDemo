# PanoramaStitchingDemo
使用Opencv拼接四张图片测试结果以及运行时间

##需要自己添加Opencv3.0 库
#导入OpenCV遇到的的错误
报错信息

报错1：enum { NO, GAIN, GAIN_BLOCKS }; Expected identifier，这个错误应该有三处，只要把NO修改成 NO_EXPOSURE_COMPENSATOR 或 NO_EXPOSURE_COMPENSATOR = 0。

报错2：缺少相应的库。解决完上一个错误之后又会报出30个错误，这是关于缺少相应的库，比如AVFoundation.framework、CoreVideo.framework、 AssetsLibrary.framework、CoreMedia.framework等，缺什么就导入什么。

3.报错"cvflann::anyimpl::bad_any_cast"，google了也有很多人碰到了相同的情况，但是解决办法却不相同。
最后看了一篇文章在“opencv_modules.cpp”文件中的“#define HAVE_OPENCV_FLANN”改成“#undef HAVE_OPENCV_FLANN”

4.报错“image.type() == CV_CU83", 说应该是图片不是三通道的错误。添加了这一行”"cvtColor(image, image,CV_RGBA2RGB);"
