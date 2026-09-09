import 'package:coelab/component.dart';
import 'package:coelab/connection.dart';

class Run{
   
     final List<Component> objects = [];
     final List<ConnectionNode> nodes =[];
  Run(List<Component> objects, List<ConnectionNode> nodes){
    this.objects.addAll(objects);
    this.nodes.addAll(nodes);
    
    for(Component object in objects){
      if(object.type==3){
        print('Wire found');
        for(Component child in object.children){
          print('Component: ${child.name},${child.compAtTerminal[0]?.type},${child.compAtTerminal[1]?.type}');

        }
      }
     
    }
 
  }
}