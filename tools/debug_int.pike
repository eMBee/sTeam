#!/usr/local/lib/steam/bin/steam

/* Copyright (C) 2000-2004  Thomas Bopp, Thorsten Hampel, Ludger Merkens
 * Copyright (C) 2003-2004  Martin Baehr
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
 *
 * $Id: debug.pike.in,v 1.1 2008/03/31 13:39:57 exodusd Exp $
 */

constant cvs_version="$Id: debug.pike.in,v 1.1 2008/03/31 13:39:57 exodusd Exp $";

inherit "/usr/local/lib/steam/tools/applauncher.pike";
#define OBJ(o) _Server->get_module("filepath:tree")->path_to_object(o)

Stdio.Readline readln;
mapping options;
int flag=1,c=1;
string pw,str;

class Handler
{
  inherit Tools.Hilfe.Evaluator;
  inherit Tools.Hilfe;

  void create(mapping _constants)
  {
    readln = Stdio.Readline();
    object p = ((program)"tab_completion.pmod")();
    readln = p->readln;
    write=predef::write;
    ::create();
    p->load_hilferc();
    p->constants+=_constants;  //For listing sTeam commands and objects on tab
    constants = p->constants;  //For running those commands
    readln->get_input_controller()->bind("\t",p->handle_completions);
  }

  void add_constants(mapping a)
  {
      constants = constants + a;
  }
/*  void add_variables(mapping a)
  {
      variables = variables + a;
  }*/
}

object _Server,users;
mapping all;
string path="/";
Stdio.Readline.History readline_history;

void ping()
{
  call_out(ping, 10);
  mixed a = conn->send_command(14, 0);
  if(a=="sTeam connection lost.")
  {
      flag = 0;
      readln->set_prompt(path+"~ ");
      conn = ((program)"client_base.pike")();
      conn->close();
      if(conn->connect_server(options->host, options->port))
      {
          remove_call_out(ping);
          ping();
          if(str=conn->login(options->user, pw, 1))
          {
          _Server=conn->SteamObj(0);
          users=_Server->get_module("users");
          handler->add_constants(assign(conn,_Server,users));
          flag=1;
          readln->set_prompt(path+"> ");
          }
      }
  }
}

object handler, conn;
mapping myarray;
int main(int argc, array(string) argv)
{
  options=init(argv);
  _Server=conn->SteamObj(0);
  users=_Server->get_module("users");
  all = assign(conn,_Server,users);
  all = all + (([

    ]));
  handler = Handler(all);
  array history=(Stdio.read_file(options->historyfile)||"")/"\n";
  if(history[-1]!="")
    history+=({""});

  readline_history=Stdio.Readline.History(512, history);

  readln->enable_history(readline_history);

  handler->add_input_line("start backend");

  string command;
  myarray = ([ "list"        : list,
    "goto"        : goto_room,
    "title"       : set_title,
    "room"        : desc_room,
    "look"        : look,
    "take"        : take,
    "gothrough"   : gothrough,
    "create"      : create_ob,
    ]);
  Regexp.SimpleRegexp a = Regexp.SimpleRegexp("[a-zA-Z]* [\"|'][a-zA-Z _-]*[\"|']");
  array(string) command_arr;
  while((command=readln->read(
           sprintf("%s", (handler->state->finishedp()?getstring(1):getstring(2))))))
  {
    if(sizeof(command))
    {
      Stdio.write_file(options->historyfile, readln->get_history()->encode());
      command = String.trim_whites(command);
      if(a->match(command))
          command_arr = array_sscanf(command,"%s [\"|']%s[\"|']");
      else
          command_arr = command/" ";
      if(myarray[command_arr[0]])
      {
        int num = sizeof(command_arr);
        mixed result = catch {
        if(num==2)
          myarray[command_arr[0]](command_arr[1]);
        else if(num==3)
          myarray[command_arr[0]](command_arr[1],command_arr[2]);
        else if(num==1)
          myarray[command_arr[0]]();
        };

        if(result!=0)
        {
          write("Wrong command.\n");
        }
      }
      else
        handler->add_input_line(command);
//      array hist = handler->history->status()/"\n";
//      if(hist)
//        if(search(hist[sizeof(hist)-3],"sTeam connection lost.")!=-1){
//          handler->write("came in here\n");
//          flag=0;
//        }
      continue;
    }
//    else { continue; }
  }
  handler->add_input_line("exit");
}

mapping init(array argv)
{
  mapping options = ([ "file":"/etc/shadow" ]);

  array opt=Getopt.find_all_options(argv,aggregate(
    ({"file",Getopt.HAS_ARG,({"-f","--file"})}),
    ({"host",Getopt.HAS_ARG,({"-h","--host"})}),
    ({"user",Getopt.HAS_ARG,({"-u","--user"})}),
    ({"port",Getopt.HAS_ARG,({"-p","--port"})}),
    ));

  options->historyfile=getenv("HOME")+"/.steam_history";

  foreach(opt, array option)
  {
    options[option[0]]=option[1];
  }
  if(!options->host)
    options->host="127.0.0.1";
  if(!options->user)
    options->user="root";
  if(!options->port)
    options->port=1900;
  else
    options->port=(int)options->port;

  string server_path = "/home/trilok/Desktop/all_gits/societyserver/sTeam";

  master()->add_include_path(server_path+"/server/include");
  master()->add_program_path(server_path+"/server/");
  master()->add_program_path(server_path+"/conf/");
  master()->add_program_path(server_path+"/spm/");
  master()->add_program_path(server_path+"/server/net/coal/");

  conn = ((program)"client_base.pike")();

  int start_time = time();

  werror("Connecting to sTeam server...\n");
  while ( !conn->connect_server(options->host, options->port)  ) 
  {
    if ( time() - start_time > 120 ) 
    {
      throw (({" Couldn't connect to server. Please check steam.log for details! \n", backtrace()}));
    }
    werror("Failed to connect... still trying ... (server running ?)\n");
    sleep(10);
  }
 
  ping();
  if(lower_case(options->user) == "guest")
    return options;

  mixed err;
  int tries=3;
  //readln->set_echo( 0 );
  do
  {
    pw = Input.read_password( sprintf("Password for %s@%s", options->user,
           options->host), "steam" );
    //pw=readln->read(sprintf("passwd for %s@%s: ", options->user, options->host));
  }
  while((err = catch(conn->login(options->user, pw, 1))) && --tries);
  //readln->set_echo( 1 );

  if ( err != 0 ) 
  {
    werror("Failed to log in!\nWrong Password!\n");
    exit(1);
  } 
  return options;
}

mapping assign(object conn, object _Server, object users)
{
	return ([
    "_Server"     : _Server,
    "get_module"  : _Server->get_module,
    "get_factory" : _Server->get_factory,
    "conn"        : conn,
    "find_object" : conn->find_object,
    "users"       : users,
    "groups"      : _Server->get_module("groups"),
    "me"          : users->lookup(options->user),
    "edit"        : applaunch,
    "create"      : create_object,
    "list"        : list,
    "goto"        : goto_room,
    "title"       : set_title,
    "room"        : desc_room,
    "look"        : look,
    "take"        : take,
    "gothrough"   : gothrough,

    // from database.h :
    "_SECURITY" : _Server->get_module("security"),
    "_FILEPATH" : _Server->get_module("filepath:tree"),
    "_TYPES" : _Server->get_module("types"),
    "_LOG" : _Server->get_module("log"),
    "OBJ" : _Server->get_module("filepath:tree")->path_to_object,
    "MODULE_USERS" : _Server->get_module("users"),
    "MODULE_GROUPS" : _Server->get_module("groups"),
    "MODULE_OBJECTS" : _Server->get_module("objects"),
    "MODULE_SMTP" : _Server->get_module("smtp"),
    "MODULE_URL" : _Server->get_module("url"),
    "MODULE_ICONS" : _Server->get_module("icons"),
    "SECURITY_CACHE" : _Server->get_module("Security:cache"),
    "MODULE_SERVICE" : _Server->get_module("ServiceManager"),
    "MOD" : _Server->get_module,
    "USER" : _Server->get_module("users")->lookup,
    "GROUP" : _Server->get_module("groups")->lookup,
    "_ROOTROOM" : _Server->get_module("filepath:tree")->path_to_object("/"),
    "_STEAMUSER" : _Server->get_module("users")->lookup("steam"),
    "_ROOT" : _Server->get_module("users")->lookup("root"),
    "_GUEST" : _Server->get_module("users")->lookup("guest"),
    "_ADMIN" : _Server->get_module("users")->lookup("admin"),
    "_WORLDUSER" : _Server->get_module("users")->lookup("everyone"),
    "_AUTHORS" : _Server->get_module("users")->lookup("authors"),
    "_REVIEWER" : _Server->get_module("users")->lookup("reviewer"),
    "_BUILDER" : _Server->get_module("users")->lookup("builder"),
    "_CODER" : _Server->get_module("users")->lookup("coder"),
    ]);
}

// create new sTeam objects
// with code taken from the web script create.pike
mixed create_object(string|void objectclass, string|void name, void|string desc, void|mapping data)
{
  if(!objectclass && !name)
  {
    write("Usage: create(string objectclass, string name, void|string desc, void|mapping data\n");
    return 0;
  }
  object _Server=conn->SteamObj(0);
  object created;
  object factory;

  if ( !stringp(objectclass))
    return "No object type submitted";

  factory = _Server->get_factory(objectclass);

  switch(objectclass)
  {
    case "Exit":
      if(!data->exit_from)
        return "exit_from missing";
      break;
    case "Link":
      if(!data->link_to)
        return "link_to missing";
      break;
  }

  if(!data)
    data=([]);
  created = factory->execute(([ "name":name ])+ data );

  if(stringp(desc))
    created->set_attribute("OBJ_DESC", desc);

//  if ( kind=="gallery" )
//  {
//    created->set_acquire_attribute("xsl:content", 0);
//    created->set_attribute("xsl:content",
//      ([ _STEAMUSER:_FILEPATH->path_to_object("/stylesheets/gallery.xsl") ])
//                          );
//  }

//  created->move(this_user());

  return created;
}

string getstring(int i)
{
//  write("came in here\n");
  if(i==1&&flag==1)
      return path+"> ";
  else if(i==1&&(flag==0))
      return path+"~ ";
  else if(i==2&&flag==1)
      return path+">> ";
  else if(i==2&&(flag==0))
      return path+"~~ ";
}

int list(string what)
{
  if(what==""||what==0)
  {
    write("Wrong usage\n");
    return 0;
  }
  int flag=0;
  string toappend="";
  array(string) display = get_list(what);
  string a="";
  if(sizeof(display)==0)
    toappend = "There are no "+what+" in this room\n";
  else
    toappend = "Here is a list of all "+what+" in the current room\n";
  foreach(display,string str)
  {
    a=a+(str+"    ");
    if(str=="Invalid command")
    {
      flag=1;
      write(str+"\n");
    }
  }
  if(flag==0)
    write(toappend+a+"\n\n");
  return 0;
}

array(string) get_list(string what)
{
//  string name;
//  object to;
  array(string) gates=({}),containers=({}),documents=({}),rooms = ({});
//  mapping(string:object) s = ([ ]);
  object pathobj = _Server->get_module("filepath:tree")->path_to_object(path);
  mixed all = pathobj->get_inventory_by_class(0x3cffffff); //CLASS_ALL
  foreach(all, object obj)
  {
    string fact_name = _Server->get_factory(obj)->query_attribute("OBJ_NAME");
    string obj_name = obj->query_attribute("OBJ_NAME");
//    write("normally : "+obj_name+"\n");
    if(fact_name=="Document.factory")
        documents = Array.push(documents,obj_name);
//          write(obj_name+"\n");
    else if(fact_name=="Exit.factory"){
        string fullgate = obj_name+" : "+obj->get_exit()->query_attribute("OBJ_NAME");
        gates = Array.push(gates,fullgate);
//          write("in gates : "+fullgate+"\n");
    }
    else if(fact_name=="Container.factory")
        containers = Array.push(containers,obj_name);
//          write("in containers : "+obj_name+"\n");
    else if(fact_name=="Room.factory")
        rooms = Array.push(rooms,obj_name);
  }
  if(what=="gates")
    return gates;
  else if(what=="rooms")
    return rooms;
  else if(what=="containers")
    return containers;
  else if(what=="files")
    return documents;
  else
    return ({"Invalid command"});
}


int goto_room(string where)
{
  string roomname="";
  object pathobj;

  if(where=="rucksack")
  {
      pathobj=users->lookup(options->user);
      path="/home/~"+pathobj->query_attribute("OBJ_NAME");
      roomname="Your rucksack";
  }
  else
  {
    pathobj = OBJ(where);
    if(!pathobj)    //Relative room checking
    {
      if(path[-1]==47)    //check last "/"
      {
        pathobj = OBJ(path+where);
        where=path+where;
      }
      else
      {
        pathobj = OBJ(path+"/"+where);
        where=path+"/"+where;
      }
    }
    roomname = pathobj->query_attribute("OBJ_NAME");
    string factory = _Server->get_factory(pathobj)->query_attribute("OBJ_NAME");
    if(pathobj&&((factory=="Room.factory")||(factory=="User.factory")))
      path = where;
    else if(pathobj)
    {
      write("Please specify path to room. Not a "+((factory/".")[0])+"\n");
      return 0;
    }
    else
    {
      write("Please specify correct path to a room.\n");
      return 0;
    }
  }
//  roomname = pathobj->query_attribute("OBJ_NAME");
  write("You are now inside "+roomname+"\n");
  return 0;
}

int set_title(string desc)
{
 if(users->lookup(options->user)->set_attribute("OBJ_DESC",desc))
    write("You are now described as - "+desc+"\n");
  else
    write("Cannot set description.\n");
  return 0;
}

int desc_room()
{
//  write("path : "+path+"\n");
  object pathobj = _Server->get_module("filepath:tree")->path_to_object(path);
  string desc = pathobj->query_attribute("OBJ_DESC");
//  write("desc : "+desc+"\n");
  if((desc=="")||(Regexp.match("^ +$",desc)))
    desc = "This room does not have a description yet.\n";
  write("You are currently in "+pathobj->query_attribute("OBJ_NAME")+"\n"+desc+"\n");
  return 0;
}

int look(string|void str)
{
  if(str)
  {
    write("Just type in 'look' to look around you\n");
    return 0;
  }
  desc_room();
  list("gates");
  list("files");
  list("containers");
  return 0;
}

int take(string name)
{
    string fullpath="";
    if(path[-1]==47)    //check last "/"
      fullpath = path+name;
    else
      fullpath = path+"/"+name;
    object orig_file = _Server->get_module("filepath:tree")->path_to_object(fullpath);
    if(orig_file)
    {
      object dup_file = orig_file->duplicate();
      object me = users->lookup(options->user);  //This is a User.factory and also the user's rucksack.
      dup_file->move(me);
      write(name+" copied to your rucksack.\n");
    }
    else
      write("Please mention a file in this room.");
    return 0;
}

int gothrough(string gatename)
{
    string fullpath = "";
    if(path[-1]==47)    //check last "/"
      fullpath = path+gatename;
    else
      fullpath = path+"/"+gatename;
    object gate = _Server->get_module("filepath:tree")->path_to_object(fullpath);
    if(gate)
    {
      object exit = gate->get_exit();
      string exit_path1 = "",exit_path2 = "";
      exit_path1 = _Server->get_module("filepath:tree")->check_tilde(exit);
      exit_path2 = _Server->get_module("filepath:tree")->object_to_path(exit);
      if(exit_path1!="")
          goto_room(exit_path1);
      else if(exit_path2!="/void/"||exit_path2!="")
          goto_room(exit_path2);
      else
          write("Problem with object_to_path\n");
    }
    else
      write(gatename+" is not reachable from current room\n");
    return 0;
}

int delete(string file_cont_name)
{
  string fullpath="";
  if(path[-1]==47)    //check last "/"
      fullpath = path+file_cont_name;
  else
      fullpath = path+"/"+file_cont_name;
  if(OBJ(fullpath))
    return 0;
  return 0;
}

int create_ob(string type,string name)
{
  string desc = readln->read("How would you describe it?\n");
  mapping data = ([]);
  type = String.capitalize(type);
  if(type=="Exit")
  {
    object exit_to = OBJ(readln->read("Where do you want to exit to?(full path)\n"));
    object exit_from = OBJ(path);
    data = ([ "exit_from":exit_from, "exit_to":exit_to ]);
  }
  else if(type=="Link")
  {
    object link_to = OBJ(readln->read("Where does the link lead?\n"));
    data = ([ "link_to":link_to ]);
  }
  object myobj = create_object(type,name,desc,data);
  if(type=="Room")
    myobj->move(OBJ(path));

  return 0;
}