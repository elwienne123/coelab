import 'package:coelab/shared/Ad_state.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';

class Banneradwidget extends StatefulWidget {
  const Banneradwidget({super.key});

  @override
  State<Banneradwidget> createState() => _BanneradwidgetState();
}

class _BanneradwidgetState extends State<Banneradwidget> {
  BannerAd? banner;

  @override
  void didChangeDependencies()
  {
    super.didChangeDependencies();
    final adState=Provider.of<AdState>(context);
    adState.initialization.then((value){
      setState(() {
        banner=BannerAd(
          adUnitId: adState.bannerAdUnitId,
          size:AdSize.banner , 
          request: const AdRequest(),
          listener: adState.bannerAdListener)..load();
         
         
        
      });
    });
     
  }
  @override
  void dispose() {
    banner!.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return (banner==null)?Container():AdWidget(ad:banner!);
  }
  
}