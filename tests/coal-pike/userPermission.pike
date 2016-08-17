#define OBJ(o) _Server->get_module("filepath:tree")->path_to_object(o)

//Tests file permissions
int test(object me,object _Server,object...args)
{
	int pass = 0;
    args[1]("testUser1","password1");
    args[1]("testUser2","password2");
	args[0]->login("testUser1","password1",1);
	_Server->get_factory("Container")->execute((["name":"testCont"]))->move(OBJ("/home/testUser1")); //object being created by user1 and it belongs to user1.
	args[0]->login("testUser2","password2",1);
	write("Trying to access container created by user1 as user2: ");
	mixed result = catch{OBJ("/home/testUser1/testCont")->delete();}; //User2 trys deleting the object belonging to user1
	if(result!=0){
		pass=1;
		write("passed\n");
	}
	else write("failed\n");
//	args[0]->login("root","steam",1);
//	user1->delete();
//	user2->delete();
	args[0]->login("TestUser","password",1);
    return pass;
}
