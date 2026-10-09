/// A long task (a report that takes minutes) without holding the request: the POST answers
/// `202 Accepted` with the `Location` of a job, the client polls it, and once it's done the job
/// answers `303 See Other` to the result.
///
/// Run: `dart run lib/async_jobs.dart`, then `curl -i -X POST localhost:8080/reports` and
/// `curl -i localhost:8080/jobs/1` until it's a 303.
library;

import 'dart:async';

import 'package:winter/winter.dart';

enum JobState { running, done, failed }

class Job {
  final int id;
  JobState state = JobState.running;
  String? result;

  Job(this.id);
}

/// Runs the jobs in the background. `work` is what a job does (a fake in the tests)
class JobRunner {
  final Future<String> Function() work;
  final Map<int, Job> _jobs = {};
  int _nextId = 1;

  JobRunner(this.work);

  Job start() {
    final Job job = _jobs[_nextId] = Job(_nextId++);
    // Not awaited: the request ends now, the job goes on
    unawaited(
      work().then(
        (result) => job
          ..result = result
          ..state = JobState.done,
        onError: (Object error, StackTrace stackTrace) {
          logger.error(
            'Job ${job.id} failed',
            error: error,
            stackTrace: stackTrace,
          );
          job.state = JobState.failed;
        },
      ),
    );
    return job;
  }

  Job find(int id) =>
      _jobs[id] ?? (throw NotFoundException(detail: 'Job $id not found'));
}

WinterRouter router(JobRunner runner) => WinterRouter(
  routes: [
    Route.post(
      path: '/reports',
      handler: (request) {
        final Job job = runner.start();
        return ResponseEntity.accepted(
          body: {'job': job.id, 'state': job.state.name},
          headers: {
            HttpHeader.location: '/jobs/${job.id}',
            // A hint for the client: ask again in 2 seconds
            HttpHeader.retryAfter: '2',
          },
        );
      },
    ),
    Route.get(
      path: '/jobs/{id|[0-9]+}',
      handler: (request) {
        final Job job = runner.find(request.pathParam<int>('id'));
        return switch (job.state) {
          JobState.running => ResponseEntity.ok(
            body: {'job': job.id, 'state': job.state.name},
            headers: {HttpHeader.retryAfter: '2'},
          ),
          JobState.done => ResponseEntity.seeOther('/reports/${job.id}'),
          JobState.failed => throw const InternalServerErrorException(
            detail: 'The report could not be generated',
          ),
        };
      },
    ),
    Route.get(
      path: '/reports/{id|[0-9]+}',
      handler: (request) {
        final Job job = runner.find(request.pathParam<int>('id'));
        if (job.state != JobState.done) {
          throw NotFoundException(detail: 'Report ${job.id} is not ready');
        }
        return ResponseEntity.ok(body: {'report': job.result});
      },
    ),
  ],
);

Future<void> main() async => Winter.start(
  router: router(
    JobRunner(() async {
      await Future<void>.delayed(const Duration(seconds: 5));
      return 'Sales of the month: 1200';
    }),
  ),
);
