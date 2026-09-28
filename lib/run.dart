import 'dart:io';

import 'package:coelab/component.dart';
import 'package:coelab/connection.dart';

class Run{
   
    final List<Component> objects = [];
    final List<ConnectionNode> nodes =[];
    final List<ConnectionNode> junctions =[];
    final List<NodeTerminal> visited =[];
    final List<NodeTerminal> branch =[];
    final List<List<double>> eqn=[];
  Run(List<Component> objects, List<ConnectionNode> nodes){
    for(int i=0; i<eqn.length; i++){
        print(eqn[i]);
    }
   
    
    this.objects.addAll(objects);
    this.nodes.addAll(nodes);
     
     for(ConnectionNode node in nodes){
        node.branches.clear();
        node.eqn.clear();
     }
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
 
      
    nodalAnalysis();
    print("/////////");
    for(int k=0; k<eqn.length; k++){
            print(eqn[k] );
   }

   for (int i = 0; i < eqn.length; i++) {

  double pivot = eqn[i][i];

  for (int k = 0; k < eqn[i].length; k++) {
    eqn[i][k] /= pivot;
  }

  for (int j = i + 1; j < eqn.length; j++) {

    double factor = eqn[j][i];

    for (int k = 0; k < eqn[j].length; k++) {
      eqn[j][k] -= factor * eqn[i][k];
    }
  }
}
    print("=========");
    for(int k=0; k<eqn.length; k++){
            print(eqn[k] );
   }
     for(ConnectionNode node in junctions){
      if(junctions.indexOf(node)<eqn.length){
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
                          branch.totalCurrent+=terminal.object.current;
                        }else{
                          branch.totalCurrent-=terminal.object.current;
                        }
                    }
                }
               }
             }
        }
    }
  }
  
  void nodalAnalysis(){
    for(ConnectionNode node in junctions){
      if(junctions.indexOf(node)<junctions.length){
        print(junctions.length);
          for(int i=0; i<junctions.length; i++){
            
            node.eqn.add(0);
          }
      }
      
    }
    for(ConnectionNode node in junctions){
     if(junctions.indexOf(node)<junctions.length-1){
      for(Branch branch in node.branches){
          int multiplier=(branch.head==node)?-1:1;
          if(branch.totalCurrent!=0){
             node.eqn[node.eqn.length-1]=branch.totalCurrent*-1*multiplier;
            
          }else{
                node.eqn[junctions.indexOf(branch.head!)]+=multiplier/branch.totalResistence;
                if(junctions.indexOf(branch.tail!)<junctions.length-1){
                node.eqn[junctions.indexOf(branch.tail!)]-=multiplier/branch.totalResistence;
                }
                if(branch.totalVoltage!=0){
                    node.eqn[node.eqn.length-1]=branch.totalVoltage/branch.totalResistence*-1*multiplier;
                }
          }
          
      }

      eqn.add(node.eqn);
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