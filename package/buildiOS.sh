cd ..
rm -rf ./build/ios/ipa/code_zero.ipa

fvm flutter build ipa --release --export-options-plist=./package/ExportOptions.plist

./package/pgyer_upload.sh -k 98e445172e8942aece1d0eac22f0270e ./build/ios/ipa/code_zero.ipa



