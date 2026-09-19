import 'package:coelab/component.dart';
import 'package:coelab/connection.dart';

class Run{
   
    final List<Component> objects = [];
    final List<ConnectionNode> nodes =[];
    final List<ConnectionNode> junctions =[];
    final List<NodeTerminal> visited =[];
    final List<NodeTerminal> branch =[];
  Run(List<Component> objects, List<ConnectionNode> nodes){
    this.objects.addAll(objects);
    this.nodes.addAll(nodes);
    for (final node in nodes) {
      if (node.terminals.length >= 3) {
        junctions.add(node);
      }
    }
    for(ConnectionNode node in junctions){
       for(NodeTerminal terminal in node.terminals){
        if(isVisited(terminal)==false){
          branch.clear();
          createBranch(terminal,node);
       }
       
        }
       
    }

   
  setValues();
  for(ConnectionNode node in junctions){
    //node.branches.clear();
    print('branches connected to node ${junctions.indexOf(node)}');
    print('branches: ${node.branches.length}');
    for(Branch branch in node.branches){
        print('Branch ${node.branches.indexOf(branch)} r: ${branch.totalResistence} v: ${branch.totalVoltage} c: ${branch.totalCurrent}');
          for(NodeTerminal terminal in branch.branch){
            print('T-${terminal.terminal} - ${terminal.object.name}');
          }
    }
    
  }
    
  }
  bool isVisited(NodeTerminal node){
    for(NodeTerminal terminal in visited){
      if(node.object==terminal.object){
       
        return true;
      }
    }
    return false;
  }
  
  void createBranch(NodeTerminal terminal, ConnectionNode origin){
   
      branch.add(terminal);
      visited.add(terminal);
      for(ConnectionNode wire in nodes){
    int i=(terminal.terminal==0)?1:0;
    if(wire.containsTerminal(terminal.object, i)){
      if(wire.terminals.length<3){
         if(wire.terminals[0].object==terminal.object){
            createBranch(wire.terminals[1], origin);
         }else{
            createBranch(wire.terminals[0], origin);
         }
      }else{
            List<NodeTerminal> newBranch =[];
            for(NodeTerminal b in branch){
            NodeTerminal newTerminal=NodeTerminal(object: b.object, terminal: b.terminal);
            newBranch.add(newTerminal);
           }
            print("tail");
            Branch branchWire=new Branch(branch: newBranch);
            
              branchWire.head=origin;
              branchWire.tail=wire;
              wire.branches.add(branchWire);
              origin.branches.add(branchWire);
            
            
      }
    }
   }
    
  }
  
  void setValues(){
    for(ConnectionNode node in junctions){
        for(Branch branch in node.branches){
             if(branch.head==node){
               for(NodeTerminal terminal in branch.branch){
                if(terminal.object.type==0){
                    branch.totalResistence+=terminal.object.resistance;
                }else if(terminal.object.type==1){
                  if(terminal.terminal==0){
                    branch.totalVoltage-=terminal.object.voltage;
                  }else{
                    branch.totalVoltage+=terminal.object.voltage;
                  }
                }else{
                    if(branch.totalCurrent==0){
                        if(terminal.terminal==0){
                          branch.totalCurrent-=terminal.object.current;
                        }else{
                          branch.totalCurrent+=terminal.object.current;
                        }
                    }
                }
               }
             }
        }
    }
  }
}

class Branch{
  List<NodeTerminal> branch=[];
  double totalVoltage=0;
  double totalCurrent=0;
  double totalResistence=0;
  ConnectionNode? head, tail;
  Branch({required this.branch});
}