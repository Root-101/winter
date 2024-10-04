import 'package:mongo_dart/mongo_dart.dart';

void main() async {
  var db = Db('mongodb://localhost:27017/stories?authSource=admin');
  await db.open();

  var coll = db.collection('UserStories');

  final get = await coll.find(where.eq('stories.storyId', 'f5cf2550-a25c-4821-b936-5b4aef8866d0')).toList();

  print(get);
}