const mongoose = require("mongoose");

module.exports = async () => {
    try {
        const connectionParams = {
            useNewUrlParser: true,
            useUnifiedTopology: true,
        };
        
        // Fix: Parse USE_DB_AUTH as boolean (env vars are always strings)
        const useDBAuthEnv = process.env.USE_DB_AUTH;
        const useDBAuth = useDBAuthEnv === "true" || useDBAuthEnv === "1";
        
        if(useDBAuth){
            connectionParams.user = process.env.MONGO_USERNAME;
            connectionParams.pass = process.env.MONGO_PASSWORD;
        }
        
        await mongoose.connect(
           process.env.MONGO_CONN_STR,
           connectionParams
        );
        console.log("Connected to database.");
    } catch (error) {
        console.log("Could not connect to database.", error);
    }
};
