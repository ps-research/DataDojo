# SQL Cookbook, 2nd Edition (Molinaro & de Graaf) — Table of Contents

_Extracted programmatically from the source PDF (pages 7–12) with `pdftotext -layout`, then parsed by `parse_toc.py`. No title or page number was transcribed by hand._

- **Preface** — p. xi

## 1. Retrieving Records — p. 1
- 1.1 Retrieving All Rows and Columns from a Table — p. 1
- 1.2 Retrieving a Subset of Rows from a Table — p. 2
- 1.3 Finding Rows That Satisfy Multiple Conditions — p. 2
- 1.4 Retrieving a Subset of Columns from a Table — p. 3
- 1.5 Providing Meaningful Names for Columns — p. 4
- 1.6 Referencing an Aliased Column in the WHERE Clause — p. 5
- 1.7 Concatenating Column Values — p. 6
- 1.8 Using Conditional Logic in a SELECT Statement — p. 7
- 1.9 Limiting the Number of Rows Returned — p. 8
- 1.10 Returning n Random Records from a Table — p. 10
- 1.11 Finding Null Values — p. 11
- 1.12 Transforming Nulls into Real Values — p. 12
- 1.13 Searching for Patterns — p. 13
- 1.14 Summing Up — p. 14

## 2. Sorting Query Results — p. 15
- 2.1 Returning Query Results in a Specified Order — p. 15
- 2.2 Sorting by Multiple Fields — p. 16
- 2.3 Sorting by Substrings — p. 17
- 2.4 Sorting Mixed Alphanumeric Data — p. 18
- 2.5 Dealing with Nulls When Sorting — p. 21
- 2.6 Sorting on a Data-Dependent Key — p. 27
- 2.7 Summing Up — p. 28

## 3. Working with Multiple Tables — p. 29
- 3.1 Stacking One Rowset atop Another — p. 29
- 3.2 Combining Related Rows — p. 31
- 3.3 Finding Rows in Common Between Two Tables — p. 33
- 3.4 Retrieving Values from One Table That Do Not Exist in Another — p. 34
- 3.5 Retrieving Rows from One Table That Do Not Correspond to Rows in Another — p. 40
- 3.6 Adding Joins to a Query Without Interfering with Other Joins — p. 42
- 3.7 Determining Whether Two Tables Have the Same Data — p. 44
- 3.8 Identifying and Avoiding Cartesian Products — p. 51
- 3.9 Performing Joins When Using Aggregates — p. 52
- 3.10 Performing Outer Joins When Using Aggregates — p. 57
- 3.11 Returning Missing Data from Multiple Tables — p. 60
- 3.12 Using NULLs in Operations and Comparisons — p. 64
- 3.13 Summing Up — p. 65

## 4. Inserting, Updating, and Deleting — p. 67
- 4.1 Inserting a New Record — p. 68
- 4.2 Inserting Default Values — p. 68
- 4.3 Overriding a Default Value with NULL — p. 70
- 4.4 Copying Rows from One Table into Another — p. 70
- 4.5 Copying a Table Definition — p. 71
- 4.6 Inserting into Multiple Tables at Once — p. 72
- 4.7 Blocking Inserts to Certain Columns — p. 74
- 4.8 Modifying Records in a Table — p. 75
- 4.9 Updating When Corresponding Rows Exist — p. 77
- 4.10 Updating with Values from Another Table — p. 78
- 4.11 Merging Records — p. 81
- 4.12 Deleting All Records from a Table — p. 83
- 4.13 Deleting Specific Records — p. 83
- 4.14 Deleting a Single Record — p. 84
- 4.15 Deleting Referential Integrity Violations — p. 85
- 4.16 Deleting Duplicate Records — p. 85
- 4.17 Deleting Records Referenced from Another Table — p. 87
- 4.18 Summing Up — p. 89

## 5. Metadata Queries — p. 91
- 5.1 Listing Tables in a Schema — p. 91
- 5.2 Listing a Table’s Columns — p. 93
- 5.3 Listing Indexed Columns for a Table — p. 94
- 5.4 Listing Constraints on a Table — p. 95
- 5.5 Listing Foreign Keys Without Corresponding Indexes — p. 97
- 5.6 Using SQL to Generate SQL — p. 100
- 5.7 Describing the Data Dictionary Views in an Oracle Database — p. 102
- 5.8 Summing Up — p. 103

## 6. Working with Strings — p. 105
- 6.1 Walking a String — p. 106
- 6.2 Embedding Quotes Within String Literals — p. 108
- 6.3 Counting the Occurrences of a Character in a String — p. 109
- 6.4 Removing Unwanted Characters from a String — p. 110
- 6.5 Separating Numeric and Character Data — p. 112
- 6.6 Determining Whether a String Is Alphanumeric — p. 116
- 6.7 Extracting Initials from a Name — p. 120
- 6.8 Ordering by Parts of a String — p. 125
- 6.9 Ordering by a Number in a String — p. 126
- 6.10 Creating a Delimited List from Table Rows — p. 132
- 6.11 Converting Delimited Data into a Multivalued IN-List — p. 136
- 6.12 Alphabetizing a String — p. 141
- 6.13 Identifying Strings That Can Be Treated as Numbers — p. 147
- 6.14 Extracting the nth Delimited Substring — p. 153
- 6.15 Parsing an IP Address — p. 160
- 6.16 Comparing Strings by Sound — p. 162
- 6.17 Finding Text Not Matching a Pattern — p. 164
- 6.18 Summing Up — p. 167

## 7. Working with Numbers — p. 169
- 7.1 Computing an Average — p. 169
- 7.2 Finding the Min/Max Value in a Column — p. 171
- 7.3 Summing the Values in a Column — p. 173
- 7.4 Counting Rows in a Table — p. 175
- 7.5 Counting Values in a Column — p. 177
- 7.6 Generating a Running Total — p. 178
- 7.7 Generating a Running Product — p. 179
- 7.8 Smoothing a Series of Values — p. 181
- 7.9 Calculating a Mode — p. 182
- 7.10 Calculating a Median — p. 185
- 7.11 Determining the Percentage of a Total — p. 187
- 7.12 Aggregating Nullable Columns — p. 190
- 7.13 Computing Averages Without High and Low Values — p. 191
- 7.14 Converting Alphanumeric Strings into Numbers — p. 193
- 7.15 Changing Values in a Running Total — p. 196
- 7.16 Finding Outliers Using the Median Absolute Deviation — p. 197
- 7.17 Finding Anomalies Using Benford’s Law — p. 201
- 7.18 Summing Up — p. 203

## 8. Date Arithmetic — p. 205
- 8.1 Adding and Subtracting Days, Months, and Years — p. 205
- 8.2 Determining the Number of Days Between Two Dates — p. 208
- 8.3 Determining the Number of Business Days Between Two Dates — p. 210
- 8.4 Determining the Number of Months or Years Between Two Dates — p. 215
- 8.5 Determining the Number of Seconds, Minutes, or Hours Between Two Dates — p. 218
- 8.6 Counting the Occurrences of Weekdays in a Year — p. 220
- 8.7 Determining the Date Difference Between the Current Record and the Next Record — p. 231
- 8.8 Summing Up — p. 237

## 9. Date Manipulation — p. 239
- 9.1 Determining Whether a Year Is a Leap Year — p. 240
- 9.2 Determining the Number of Days in a Year — p. 246
- 9.3 Extracting Units of Time from a Date — p. 249
- 9.4 Determining the First and Last Days of a Month — p. 252
- 9.5 Determining All Dates for a Particular Weekday Throughout a Year — p. 255
- 9.6 Determining the Date of the First and Last Occurrences of a Specific Weekday in a Month — p. 261
- 9.7 Creating a Calendar — p. 268
- 9.8 Listing Quarter Start and End Dates for the Year — p. 281
- 9.9 Determining Quarter Start and End Dates for a Given Quarter — p. 286
- 9.10 Filling in Missing Dates — p. 293
- 9.11 Searching on Specific Units of Time — p. 301
- 9.12 Comparing Records Using Specific Parts of a Date — p. 302
- 9.13 Identifying Overlapping Date Ranges — p. 305
- 9.14 Summing Up — p. 311

## 10. Working with Ranges — p. 313
- 10.1 Locating a Range of Consecutive Values — p. 313
- 10.2 Finding Differences Between Rows in the Same Group or Partition — p. 317
- 10.3 Locating the Beginning and End of a Range of Consecutive Values — p. 323
- 10.4 Filling in Missing Values in a Range of Values — p. 326
- 10.5 Generating Consecutive Numeric Values — p. 330
- 10.6 Summing Up — p. 333

## 11. Advanced Searching — p. 335
- 11.1 Paginating Through a Result Set — p. 335
- 11.2 Skipping n Rows from a Table — p. 338
- 11.3 Incorporating OR Logic When Using Outer Joins — p. 339
- 11.4 Determining Which Rows Are Reciprocals — p. 341
- 11.5 Selecting the Top n Records — p. 343
- 11.6 Finding Records with the Highest and Lowest Values — p. 344
- 11.7 Investigating Future Rows — p. 345
- 11.8 Shifting Row Values — p. 347
- 11.9 Ranking Results — p. 350
- 11.10 Suppressing Duplicates — p. 351
- 11.11 Finding Knight Values — p. 353
- 11.12 Generating Simple Forecasts — p. 359
- 11.13 Summing Up — p. 367

## 12. Reporting and Reshaping — p. 369
- 12.1 Pivoting a Result Set into One Row — p. 369
- 12.2 Pivoting a Result Set into Multiple Rows — p. 372
- 12.3 Reverse Pivoting a Result Set — p. 377
- 12.4 Reverse Pivoting a Result Set into One Column — p. 379
- 12.5 Suppressing Repeating Values from a Result Set — p. 382
- 12.6 Pivoting a Result Set to Facilitate Inter-Row Calculations — p. 384
- 12.7 Creating Buckets of Data, of a Fixed Size — p. 386
- 12.8 Creating a Predefined Number of Buckets — p. 388
- 12.9 Creating Horizontal Histograms — p. 390
- 12.10 Creating Vertical Histograms — p. 392
- 12.11 Returning Non-GROUP BY Columns — p. 394
- 12.12 Calculating Simple Subtotals — p. 397
- 12.13 Calculating Subtotals for All Possible Expression Combinations — p. 400
- 12.14 Identifying Rows That Are Not Subtotals — p. 410
- 12.15 Using Case Expressions to Flag Rows — p. 412
- 12.16 Creating a Sparse Matrix — p. 414
- 12.17 Grouping Rows by Units of Time — p. 416
- 12.18 Performing Aggregations over Different Groups/Partitions Simultaneously — p. 420
- 12.19 Performing Aggregations over a Moving Range of Values — p. 422
- 12.20 Pivoting a Result Set with Subtotals — p. 429
- 12.21 Summing Up — p. 434

## 13. Hierarchical Queries — p. 435
- 13.1 Expressing a Parent-Child Relationship — p. 436
- 13.2 Expressing a Child-Parent-Grandparent Relationship — p. 440
- 13.3 Creating a Hierarchical View of a Table — p. 444
- 13.4 Finding All Child Rows for a Given Parent Row — p. 449
- 13.5 Determining Which Rows Are Leaf, Branch, or Root Nodes — p. 450
- 13.6 Summing Up — p. 458

## 14. Odds ’n’ Ends — p. 459
- 14.1 Creating Cross-Tab Reports Using SQL Server’s PIVOT Operator — p. 459
- 14.2 Unpivoting a Cross-Tab Report Using SQL Server’s UNPIVOT Operator — p. 461
- 14.3 Transposing a Result Set Using Oracle’s MODEL Clause — p. 463
- 14.4 Extracting Elements of a String from Unfixed Locations — p. 467
- 14.5 Finding the Number of Days in a Year (an Alternate Solution for Oracle) — p. 470
- 14.6 Searching for Mixed Alphanumeric Strings — p. 472
- 14.7 Converting Whole Numbers to Binary Using Oracle — p. 474
- 14.8 Pivoting a Ranked Result Set — p. 477
- 14.9 Adding a Column Header into a Double Pivoted Result Set — p. 481
- 14.10 Converting a Scalar Subquery to a Composite Subquery in Oracle — p. 493
- 14.11 Parsing Serialized Data into Rows — p. 495
- 14.12 Calculating Percent Relative to Total — p. 500
- 14.13 Testing for Existence of a Value Within a Group — p. 502
- 14.14 Summing Up — p. 505

## Appendix A. Window Function Refresher — p. 507

## Appendix B. Common Table Expressions — p. 535
- **Index** — p. 539
