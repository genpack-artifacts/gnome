#!/bin/sh
# ref: obs-plugins/files/build.d/obs-multi-rtmp.sh
# obs-multi-rtmp をローカルビルドで導入する。
# 経緯: GitHub リリースの .deb 配布版には OBS がクラッシュする 2種のバグがあり、
# ソースへ下記パッチを当ててビルドする方式へ切り替えた (2026-10 検証)。
#   1. Qtコンボボックスの再入破壊: エンコーダ一覧の再構築 (clear+addItem) 中に
#      currentIndexChanged が再帰発火し、シグナル処理中のウィジェットが clear() で
#      破棄され SIGSEGV。再構築を blockSignals(true/false) で囲む。
#   2. WHIP 選択時の std::string = nullptr: Gentoo の obs-studio は ENABLE_WEBRTC=OFF
#      (libdatachannel が Portage に無い) でビルドされ whip_output が存在しない。
#      libobs は不明な出力型に対して NULL ではなくダミー出力を返すため単純な NULL
#      ガードを抜けてしまい、コーデック宣言の NULL を std::string へ代入して UB→SIGSEGV。
#      obs_service_create/obs_output_create の NULL チェックと ClearProperties、
#      codec 宣言の NULL 安全な代入 (ac ? ac : "") へ修正。
# ソース: sorayuki/obs-multi-rtmp 0.7.4.4-15-g245d872 (commit 245d872d171f...)
# ビルド依存: dev-build/cmake (buildtime_packages)。libobs / obs-frontend-api / Qt6 は
#   media-video/obs-studio のインストールにより Lower 層に存在する。
# 注意: SRT で HEVC を選ぶには obs-studio の mpegts USE フラグ (新 mpegts 出力、
#   "h264;hevc" 宣言) が必要。use(media-video/obs-studio) への追加を検討すること。
# 注意: 上流の cmake は今も旧ロケーション (lib/obs-plugins, share/obs/obs-plugins) 前提の
#   ため cmake --install は使わず、ビルド成果物を新ロケーションへ手動コピーする。
#   gs_image_file API 非使用なので OBS 33.0 の libnsgif 1.0.0 変更の影響は受けない。
set -e

arch=$(uname -m)
if [ "$arch" != "x86_64" ]; then
  printf 'Unsupported architecture (%s). Skipping obs-multi-rtmp.\n' "$arch" >&2
  exit 0
fi

commit=245d872d171f954828939e6cd1aea3df9a5e41fa
src=/tmp/obs-multi-rtmp-src
patch_file=/tmp/obs-multi-rtmp-fix.patch

echo "Building obs-multi-rtmp from source (0.7.4.4-15-g245d872)..."
rm -rf "$src" "$patch_file"
mkdir -p "$src"
download "https://github.com/sorayuki/obs-multi-rtmp/archive/${commit}.tar.gz" > /tmp/obs-multi-rtmp.tar.gz
tar xzf /tmp/obs-multi-rtmp.tar.gz -C "$src" --strip-components=1

cat > "$patch_file" <<'PATCH'
diff --git a/src/edit-widget.cpp b/src/edit-widget.cpp
index 122a5ba..b586f14 100644
--- a/src/edit-widget.cpp
+++ b/src/edit-widget.cpp
@@ -451,6 +451,11 @@ protected:
         }
 
         auto service = obs_service_create(protocol_info->serviceId, ("tmp_service_" + targetid_).c_str(), from_json(config_->serviceParam), nullptr);
+        if (!service) {
+            blog(LOG_ERROR, TAG "Service type \"%s\" is not available in this OBS build.", protocol_info->serviceId);
+            serviceSettings_->ClearProperties();
+            return;
+        }
         serviceSettings_->UpdateProperties(
             obs_service_properties(service),
             obs_service_get_settings(service));
@@ -467,11 +472,22 @@ protected:
         }
 
         auto output = obs_output_create(protocol_info->outputId, ("tmp_output_" + targetid_).c_str(), from_json(config_->outputParam), nullptr);
+        if (!output) {
+            blog(LOG_ERROR, TAG "Output type \"%s\" is not available in this OBS build.", protocol_info->outputId);
+            outputSettings_->ClearProperties();
+            supported_audio_encoders_ = "";
+            supported_video_encoders_ = "";
+            if (aenc_ && venc_)
+                LoadEncoders();
+            return;
+        }
         outputSettings_->UpdateProperties(
             obs_output_properties(output),
             obs_output_get_settings(output));
-        supported_audio_encoders_ = obs_output_get_supported_audio_codecs(output);
-        supported_video_encoders_ = obs_output_get_supported_video_codecs(output);
+        auto ac = obs_output_get_supported_audio_codecs(output);
+        auto vc = obs_output_get_supported_video_codecs(output);
+        supported_audio_encoders_ = ac ? ac : "";
+        supported_video_encoders_ = vc ? vc : "";
         obs_output_release(output);
 
         if (aenc_ && venc_)
@@ -728,6 +744,7 @@ public:
             // Video encoders
             auto old_venc = venc_->currentData();
             std::sregex_token_iterator it(supported_video_encoders_.begin(), supported_video_encoders_.end(), sp, -1), itend;
+            venc_->blockSignals(true);
             venc_->clear();
 	        venc_->addItem(obs_module_text("SameAsOBS"), OBS_STREAMING_ENC_PLACEHOLDER);
 	        venc_->addItem(obs_module_text("SameAsOBSRecording"), OBS_RECORDING_ENC_PLACEHOLDER);
@@ -741,12 +758,14 @@ public:
             auto idx = venc_->findData(old_venc);
             if (idx >= 0)
                 venc_->setCurrentIndex(idx);
+            venc_->blockSignals(false);
         }
 
         {
             // Audio encoders
             auto old_aenc = aenc_->currentData();
             std::sregex_token_iterator it(supported_audio_encoders_.begin(), supported_audio_encoders_.end(), sp, -1), itend;
+            aenc_->blockSignals(true);
             aenc_->clear();
 	        aenc_->addItem(obs_module_text("SameAsOBS"), OBS_STREAMING_ENC_PLACEHOLDER);
 	        aenc_->addItem(obs_module_text("SameAsOBSRecording"), OBS_RECORDING_ENC_PLACEHOLDER);
@@ -760,6 +779,7 @@ public:
             auto idx = aenc_->findData(old_aenc);
             if (idx >= 0)
                 aenc_->setCurrentIndex(idx);
+            aenc_->blockSignals(false);
         }
     }
 
@@ -811,7 +831,9 @@ public:
         auto newProtocolIndex = protocolSelector_->findData(QString::fromUtf8(config_->protocol));
         // fallback to RTMP if protocol is invalid - do we really need this line?
         if (newProtocolIndex == -1) newProtocolIndex = 0;
+        protocolSelector_->blockSignals(true);
         protocolSelector_->setCurrentIndex(newProtocolIndex);
+        protocolSelector_->blockSignals(false);
 
         auto ve = venc_->currentData();
 
@@ -996,7 +1018,9 @@ public:
         name_->setText(QString::fromUtf8(target.name));
         auto protocolIndex = protocolSelector_->findData(QString::fromUtf8(target.protocol));
         if (protocolIndex < 0) protocolIndex = 0;
+        protocolSelector_->blockSignals(true);
         protocolSelector_->setCurrentIndex(protocolIndex);
+        protocolSelector_->blockSignals(false);
         syncStart_->setChecked(target.syncStart);
         syncStop_->setChecked(target.syncStop);
     }
@@ -1016,15 +1040,18 @@ public:
             }
 
             auto idx = venc_->findData(encoderId);
+            venc_->blockSignals(true);
             if (idx > max_video_encoder_placeholder_index)
                 venc_->setCurrentIndex(idx);
             else {
                 if (idx < 0)
                     idx = 0;
                 venc_->setCurrentIndex(idx);
+                venc_->blockSignals(false);
                 videoEncoderSettings_->ClearProperties();
                 return;
             }
+            venc_->blockSignals(false);
         }
 
         assert(pconfig != nullptr);
@@ -1077,15 +1104,18 @@ public:
             }
 
             auto idx = aenc_->findData(encoderId);
+            aenc_->blockSignals(true);
             if (idx > max_audio_encoder_placeholder_index)
                 aenc_->setCurrentIndex(idx);
             else {
                 if (idx < 0)
                     idx = 0;
                 aenc_->setCurrentIndex(idx);
+                aenc_->blockSignals(false);
                 audioEncoderSettings_->ClearProperties();
                 return;
             }
+            aenc_->blockSignals(false);
         }
 
         assert(pconfig != nullptr);
diff --git a/src/obs-properties-widget.cpp b/src/obs-properties-widget.cpp
index ffe7db8..e701836 100644
--- a/src/obs-properties-widget.cpp
+++ b/src/obs-properties-widget.cpp
@@ -162,6 +162,7 @@ namespace {
                 switch(propType) {
                     case OBS_PROPERTY_LIST: {
                         auto cb = static_cast<QComboBox*>(ctrl);
+                        cb->blockSignals(true);
                         for(int i = cb->count() - 1; i >= 0; --i)
                             cb->removeItem(i);
                         cbType = obs_property_list_format(p);
@@ -177,6 +178,7 @@ namespace {
                                 data = LoadCString(obs_property_list_item_string(p, i));
                             cb->addItem(LoadCString(itemname), data);
                         }
+                        cb->blockSignals(false);
                     }
                     default:
                         blog(LOG_WARNING, "ReloadProperty did not handle property of type %d", propType);
@@ -223,7 +225,9 @@ namespace {
                 
                 auto findRes = cb->findData(v);
                 if (findRes >= 0) {
+                    cb->blockSignals(true);
                     cb->setCurrentIndex(findRes);
+                    cb->blockSignals(false);
                 }
                 break;
             }
PATCH

patch -d "$src" -p1 < "$patch_file"

cmake -S "$src" -B "$src/build" \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DENABLE_FRONTEND_API=ON \
  -DENABLE_QT=ON \
  -DCMAKE_CXX_STANDARD=20 \
  -DCMAKE_CXX_STANDARD_REQUIRED=ON
cmake --build "$src/build" -j"$(nproc)"

plugin_module_dir=/usr/lib64/obs-modules/plugins
plugin_data_dir=/usr/share/obs/obs-modules/plugins/obs-multi-rtmp

mkdir -p "$plugin_module_dir" "$plugin_data_dir"
cp "$src/build/obs-multi-rtmp.so" "$plugin_module_dir"/
cp -r "$src/build/rundir/RelWithDebInfo/obs-multi-rtmp/." "$plugin_data_dir"/

rm -rf "$src" /tmp/obs-multi-rtmp.tar.gz "$patch_file"
