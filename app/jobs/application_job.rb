# frozen_string_literal: true

class ApplicationJob < ActiveJob::Base
  # Solid Queue keeps its jobs in the primary database. Thus a job that is enqueued in a
  # transaction is written in the same transaction: a rollback removes the job, and a worker
  # cannot see the job before the commit. Do not defer the enqueue to after the commit.
  self.enqueue_after_transaction_commit = false
end
