# frozen_string_literal: true

# Paper Trail v15.x hardcodes PostgreSQL-only `ILIKE` operator in its JSON
# query helpers (`where_object_changes`, `where_object_changes_to`,
# `where_object_changes_from`). MySQL does not support ILIKE, so we patch
# these methods to use the MySQL-compatible `LIKE` operator instead.
# MySQL LIKE is already case-insensitive under the utf8mb4_unicode_ci
# collation used by the versions table, so the behaviour is equivalent.

module PaperTrailMysqlCompat
  module WhereObjectChangesJsonPatch
    private

    def json
      predicates = []
      values = []
      @attributes.each do |field, value|
        predicates.push(
          "((object_changes->>? LIKE ?) OR (object_changes->>? LIKE ?))"
        )
        values.concat([field, "[#{value.to_json},%", field, "[%,#{value.to_json}]%"])
      end
      sql = predicates.join(" and ")
      @version_model_class.where(sql, *values)
    end
  end

  module WhereObjectChangesToJsonPatch
    private

    def json
      predicates = []
      values = []
      @attributes.each do |field, value|
        predicates.push(
          "(object_changes->>? LIKE ?)"
        )
        values.concat([field, "[%#{value.to_json}]"])
      end
      sql = predicates.join(" and ")
      @version_model_class.where(sql, *values)
    end
  end

  module WhereObjectChangesFromJsonPatch
    private

    def json
      predicates = []
      values = []
      @attributes.each do |field, value|
        predicates.push(
          "(object_changes->>? LIKE ?)"
        )
        values.concat([field, "[#{value.to_json},%"])
      end
      sql = predicates.join(" and ")
      @version_model_class.where(sql, *values)
    end
  end
end

Rails.application.config.after_initialize do
  PaperTrail::Queries::Versions::WhereObjectChanges.prepend(PaperTrailMysqlCompat::WhereObjectChangesJsonPatch)
  PaperTrail::Queries::Versions::WhereObjectChangesTo.prepend(PaperTrailMysqlCompat::WhereObjectChangesToJsonPatch)
  PaperTrail::Queries::Versions::WhereObjectChangesFrom.prepend(PaperTrailMysqlCompat::WhereObjectChangesFromJsonPatch)
end
