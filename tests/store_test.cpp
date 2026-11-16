#include <gtest/gtest.h>
#include <store.hpp>

TEST(Store, Doubles) {
    EXPECT_EQ(store_get(21), 42);
}
